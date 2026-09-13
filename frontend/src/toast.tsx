import { createContext, useCallback, useContext, useState } from "react";
import type { ReactNode } from "react";

type Toast = { id: number; text: string; kind: "ok" | "error" };
const ToastContext = createContext<(text: string, kind?: "ok" | "error") => void>(
  () => {}
);

let seq = 0;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const push = useCallback((text: string, kind: "ok" | "error" = "ok") => {
    const id = ++seq;
    setToasts((ts) => [...ts, { id, text, kind }]);
    setTimeout(() => setToasts((ts) => ts.filter((t) => t.id !== id)), 4000);
  }, []);

  return (
    <ToastContext.Provider value={push}>
      {children}
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.kind === "error" ? "error" : ""}`}>
          {t.text}
        </div>
      ))}
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
