import { useCallback } from "react";

const API_BASE = "/api/v1";

declare global {
  const shopify: {
    idToken: () => Promise<string>;
  };
}

async function getSessionToken(): Promise<string> {
  const token = await shopify.idToken();
  return token;
}

export function useAuthenticatedFetch() {
  return useCallback(async (path: string, options: RequestInit = {}) => {
    const token = await getSessionToken();

    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: {
        ...options.headers,
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    return response.json();
  }, []);
}
