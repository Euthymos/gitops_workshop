import { useEffect, useState } from 'react';

const DEFAULT_NAME = 'Jožko Mrkvička';

export default function App() {
  const [name, setName] = useState(DEFAULT_NAME);
  const [source, setSource] = useState('default');

  useEffect(() => {
    let alive = true;

    const loadConfig = async () => {
      try {
        const response = await fetch('/config.json', { cache: 'no-store' });
        if (!response.ok) {
          return;
        }
        const data = await response.json();
        const configuredName = typeof data.attendeeName === 'string' ? data.attendeeName.trim() : '';
        if (alive && configuredName) {
          setName(configuredName);
          setSource('config.json');
        }
      } catch (error) {
        // Fall back to the default name when config is unavailable.
      }
    };

    loadConfig();

    return () => {
      alive = false;
    };
  }, []);

  return (
    <main className="layout">
      <section className="card">
        <p className="eyebrow">GitOps Workshop pre OSK MV SR</p>
        <h1 className="headline">Ahoj, {name}!</h1>
        <p className="subtitle">Ďakujeme Ti za Tvoju aktívnu účasť na workshope.</p>
        <div className="meta">
          <p>
            Pre zmenu oslovenia uprav ConfigMap so súborom <code>config.json</code>.
          </p>
          <p className="source">Súčasný zdroj: {source}</p>
        </div>
      </section>
    </main>
  );
}
