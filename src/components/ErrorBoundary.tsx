import React, { Component, ErrorInfo, ReactNode } from "react";
import { View, Text, StyleSheet, TouchableOpacity, SafeAreaView, Platform } from "react-native";
import * as Application from "expo-application";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
  isReported: boolean;
}

export class GlobalErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
    isReported: false,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error, isReported: false };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Uncaught error:", error, errorInfo);
    this.reportCrash(error, errorInfo);
  }

  private async reportCrash(error: Error, errorInfo: ErrorInfo) {
    try {
      const deviceInfo = `${Platform.OS} ${Platform.Version}`;
      const appVersion = Application.nativeApplicationVersion || "unknown";

      // Backend (VPS) API Endpoint
      await fetch("https://deflation-shaded-sterility.ngrok-free.dev/report-crash", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          error: error.message || error.toString(),
          stack_trace: errorInfo.componentStack || error.stack,
          device_info: deviceInfo,
          app_version: appVersion,
        }),
      });

      this.setState({ isReported: true });
    } catch (err) {
      console.warn("Failed to report crash to backend:", err);
    }
  }

  private handleReset = () => {
    this.setState({ hasError: false, error: null, isReported: false });
  };

  public render() {
    if (this.state.hasError) {
      return (
        <SafeAreaView style={styles.container}>
          <View style={styles.content}>
            <Text style={styles.title}>Oops! Uygulama Çöktü 🤕</Text>
            <Text style={styles.description}>
              Beklenmedik bir hata oluştu ve uygulama kapanmak zorunda kaldı.
            </Text>
            
            {this.state.isReported ? (
              <Text style={styles.reportedText}>
                ✅ Hata raporu otomatik olarak geliştiriciye (GitHub Issues) iletildi. En kısa sürede çözülecektir!
              </Text>
            ) : (
              <Text style={styles.reportingText}>
                Hata raporu sunucuya gönderiliyor...
              </Text>
            )}

            <TouchableOpacity style={styles.button} onPress={this.handleReset}>
              <Text style={styles.buttonText}>Uygulamayı Yeniden Başlat</Text>
            </TouchableOpacity>

            <View style={styles.errorBox}>
              <Text style={styles.errorText} numberOfLines={3}>
                {this.state.error?.message}
              </Text>
            </View>
          </View>
        </SafeAreaView>
      );
    }

    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#F2F2F7",
  },
  content: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#1C1C1E",
    marginBottom: 12,
    textAlign: "center",
  },
  description: {
    fontSize: 16,
    color: "#3A3A3C",
    textAlign: "center",
    marginBottom: 24,
    lineHeight: 22,
  },
  reportedText: {
    fontSize: 14,
    color: "#34C759",
    textAlign: "center",
    fontWeight: "600",
    marginBottom: 32,
    padding: 12,
    backgroundColor: "#E5F9E7",
    borderRadius: 8,
    overflow: "hidden",
  },
  reportingText: {
    fontSize: 14,
    color: "#FF9500",
    textAlign: "center",
    fontWeight: "600",
    marginBottom: 32,
  },
  button: {
    backgroundColor: "#007AFF",
    paddingHorizontal: 24,
    paddingVertical: 14,
    borderRadius: 12,
    width: "100%",
    alignItems: "center",
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
  },
  errorBox: {
    marginTop: 32,
    padding: 16,
    backgroundColor: "#FFEBEB",
    borderRadius: 8,
    width: "100%",
  },
  errorText: {
    color: "#FF3B30",
    fontSize: 12,
    fontFamily: Platform.OS === "ios" ? "Menlo" : "monospace",
  },
});
