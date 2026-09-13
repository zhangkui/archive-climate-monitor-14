import type { ReactNode } from "react";

export function Tag({
  tone,
  children
}: {
  tone: "critical" | "warning" | "info" | "good" | "muted" | "resolved" | "false_positive" | "dismissed";
  children: ReactNode;
}) {
  return <span className={`tag ${tone}`}>{children}</span>;
}

export function Modal({
  title,
  onClose,
  children
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}

export const fmtTime = (s?: string | null) =>
  s ? new Date(s).toLocaleString("zh-CN", { hour12: false }) : "—";

export const fmtMinute = (s?: string | null) =>
  s
    ? new Date(s).toLocaleString("zh-CN", {
        hour12: false,
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      })
    : "—";
