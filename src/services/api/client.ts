import { useSettingsStore } from '../../store/useSettingsStore';

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export const fetchClient = async <T>(
  endpoint: string, 
  options: RequestInit = {}
): Promise<T> => {
  const city = useSettingsStore.getState().getCurrentCity();
  const baseUrl = city.apiBaseUrl;
  const url = `${baseUrl}${endpoint}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      throw new ApiError(`API Error: ${response.statusText}`, response.status);
    }

    // Beklenen format JSON
    const data = await response.json();
    return data as T;
  } catch (error) {
    console.error(`API Call failed: ${url}`, error);
    throw error;
  }
};
