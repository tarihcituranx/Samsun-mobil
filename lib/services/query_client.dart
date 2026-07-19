import 'dart:async';
import 'package:flutter/material.dart';

/// Basit ve bağımlılıksız bir React Query (TanStack Query) benzeri mimari.
/// Veriyi önbellekte (cache) tutar, periyodik yenileme (polling) yapar ve
/// sayfa kapandığında arka plandaki işlemleri otomatik durdurur.
class QueryClient {
  static final QueryClient _instance = QueryClient._internal();
  factory QueryClient() => _instance;
  QueryClient._internal();

  final Map<String, _QueryCacheItem<dynamic>> _cache = {};

  /// Belirtilen [queryKey] için bir sorgu oluşturur veya var olanı döndürür.
  Stream<QueryState<T>> useQuery<T>({
    required String queryKey,
    required Future<T> Function() queryFn,
    Duration? refetchInterval,
    Duration staleTime = const Duration(minutes: 5),
  }) {
    if (!_cache.containsKey(queryKey)) {
      _cache[queryKey] = _QueryCacheItem<T>(
        queryFn: queryFn,
        refetchInterval: refetchInterval,
        staleTime: staleTime,
      );
    }

    final item = _cache[queryKey]! as _QueryCacheItem<T>;
    item.addSubscriber(); // Yeni bir UI bileşeni dinlemeye başladı
    return item.stream;
  }

  /// Bileşen yok edildiğinde (dispose) aboneyi kaldırır.
  void removeSubscriber(String queryKey) {
    if (_cache.containsKey(queryKey)) {
      final item = _cache[queryKey]!;
      item.removeSubscriber();
      // Eğer kimse dinlemiyorsa önbellekten silebilir veya uykuya alabiliriz
      // Biz React Query gibi veriyi bir süre uykuya alıp arkada tutacağız.
    }
  }

  /// Önbelleği manuel temizleme (Örn: Çıkış yapıldığında)
  void clearCache() {
    for (var item in _cache.values) {
      item.dispose();
    }
    _cache.clear();
  }
}

class QueryState<T> {
  final T? data;
  final bool isLoading;
  final bool isError;
  final String? errorMessage;
  final DateTime updatedAt;

  QueryState({
    this.data,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
    required this.updatedAt,
  });
}

class _QueryCacheItem<T> {
  final Future<T> Function() queryFn;
  final Duration? refetchInterval;
  final Duration staleTime;

  Timer? _timer;
  int _subscriberCount = 0;
  
  final StreamController<QueryState<T>> _controller = StreamController<QueryState<T>>.broadcast();
  QueryState<T> _currentState = QueryState<T>(isLoading: true, updatedAt: DateTime.now());

  _QueryCacheItem({
    required this.queryFn,
    this.refetchInterval,
    required this.staleTime,
  });

  Stream<QueryState<T>> get stream => _controller.stream;

  void addSubscriber() {
    _subscriberCount++;
    
    // Anında mevcut durumu yeni aboneye gönder
    _controller.add(_currentState);

    // İlk defa abone olunuyorsa veya veri bayatsa hemen çek
    final isStale = DateTime.now().difference(_currentState.updatedAt) > staleTime;
    if (_currentState.data == null || isStale) {
      _fetch();
    }

    // Periyodik yenileme ayarlanmışsa timer'ı başlat
    if (refetchInterval != null && _timer == null) {
      _timer = Timer.periodic(refetchInterval!, (_) => _fetch());
    }
  }

  void removeSubscriber() {
    _subscriberCount--;
    if (_subscriberCount <= 0) {
      _subscriberCount = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _fetch() async {
    // Zaten yükleniyorsa tekrar tetikleme
    if (_currentState.isLoading && _currentState.data == null) return;

    _currentState = QueryState<T>(
      data: _currentState.data,
      isLoading: true,
      updatedAt: _currentState.updatedAt,
    );
    _controller.add(_currentState);

    try {
      final result = await queryFn();
      _currentState = QueryState<T>(
        data: result,
        isLoading: false,
        updatedAt: DateTime.now(),
      );
      _controller.add(_currentState);
    } catch (e) {
      _currentState = QueryState<T>(
        data: _currentState.data,
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
      _controller.add(_currentState);
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// React Query'nin [useQuery] hook'una benzer çalışan akıllı Widget.
class QueryBuilder<T> extends StatefulWidget {
  final String queryKey;
  final Future<T> Function() queryFn;
  final Duration? refetchInterval;
  final Duration staleTime;
  final Widget Function(BuildContext context, QueryState<T> state) builder;

  const QueryBuilder({
    Key? key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.refetchInterval,
    this.staleTime = const Duration(minutes: 5),
  }) : super(key: key);

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  late Stream<QueryState<T>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = QueryClient().useQuery<T>(
      queryKey: widget.queryKey,
      queryFn: widget.queryFn,
      refetchInterval: widget.refetchInterval,
      staleTime: widget.staleTime,
    );
  }

  @override
  void dispose() {
    QueryClient().removeSubscriber(widget.queryKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueryState<T>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data!);
        }
        // İlk yükleme esnasında
        return widget.builder(
          context, 
          QueryState<T>(isLoading: true, updatedAt: DateTime.now())
        );
      },
    );
  }
}
