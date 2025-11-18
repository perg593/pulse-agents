import { useState, ReactNode } from 'react';

interface CollapsibleSectionProps {
  title: string;
  defaultOpen?: boolean;
  children: ReactNode;
  actions?: ReactNode; // Phase 4.6: Optional action buttons (e.g., Reset Group)
}

export function CollapsibleSection({ title, defaultOpen = true, children, actions }: CollapsibleSectionProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  const handleToggle = () => {
    setIsOpen(!isOpen);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleToggle();
    }
  };

  return (
    <div className="collapsible-section">
      <div
        className="collapsible-header"
        onClick={handleToggle}
        onKeyDown={handleKeyDown}
        role="button"
        tabIndex={0}
        aria-expanded={isOpen}
      >
        <span className="collapsible-title">{title}</span>
        <div className="collapsible-header-actions" onClick={(e) => e.stopPropagation()}>
          {actions}
          <span className="collapsible-icon">{isOpen ? '▼' : '▶'}</span>
        </div>
      </div>
      {isOpen && (
        <div className="collapsible-content">
          {children}
        </div>
      )}
    </div>
  );
}

