import { useEffect } from "react";
import { Checkmark, Close, WarningAlt } from "@carbon/icons-react";

interface ToastProps {
  message: string;
  variant?: "success" | "error";
  onDismiss: () => void;
  duration?: number;
}

export default function Toast({ message, variant = "success", onDismiss, duration = 3500 }: ToastProps) {
  useEffect(() => {
    const timer = setTimeout(onDismiss, duration);
    return () => clearTimeout(timer);
  }, [onDismiss, duration]);

  const Icon = variant === "error" ? WarningAlt : Checkmark;

  return (
    <div className={`toast toast--${variant}`} role={variant === "error" ? "alert" : "status"} aria-live={variant === "error" ? "assertive" : "polite"}>
      <span className="toast-icon">
        <Icon size={16} />
      </span>
      <span className="toast-message">{message}</span>
      <button className="toast-close" onClick={onDismiss} aria-label="Dismiss">
        <Close size={14} />
      </button>
    </div>
  );
}
