import { useThemeStore } from '../stores/themeStore';

export function ViewportToggle() {
  const viewport = useThemeStore((state) => state.viewport);
  const setViewport = useThemeStore((state) => state.setViewport);

  return (
    <div className="viewport-toggle">
      <button
        className={viewport === 'desktop' ? 'active' : ''}
        onClick={() => setViewport('desktop')}
      >
        Desktop
      </button>
      <button
        className={viewport === 'mobile' ? 'active' : ''}
        onClick={() => setViewport('mobile')}
      >
        Mobile
      </button>
    </div>
  );
}
