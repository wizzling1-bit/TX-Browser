import React from 'react';
import { LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  description: string;
  action?: {
    label: string;
    onClick: () => void;
    icon?: LucideIcon;
  };
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  icon: Icon,
  title,
  description,
  action,
}) => {
  return (
    <div className="py-14 px-4 flex flex-col items-center justify-center text-center animate-fade-in">
      <div className="w-12 h-12 rounded-2xl bg-tx-card border border-tx-border/60 flex items-center justify-center text-tx-gold shadow-card mb-3.5">
        <Icon className="w-6 h-6" />
      </div>
      <h4 className="text-sm font-semibold text-tx-cream tracking-tight mb-1">{title}</h4>
      <p className="text-xs text-tx-textMuted max-w-sm mb-5 leading-relaxed">{description}</p>
      {action && (
        <button
          onClick={action.onClick}
          className="px-4 py-2 rounded-xl bg-tx-gold hover:bg-tx-goldLight text-black text-xs font-semibold flex items-center gap-2 transition-all shadow-glow active:scale-95"
        >
          {action.icon && <action.icon className="w-3.5 h-3.5" />}
          <span>{action.label}</span>
        </button>
      )}
    </div>
  );
};
