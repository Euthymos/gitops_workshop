import { render, screen, waitFor } from '@testing-library/react';
import App from './App';

const mockFetch = (data) =>
  vi.fn().mockResolvedValue({
    ok: true,
    json: () => Promise.resolve(data),
  });

const mockFetchFail = () =>
  vi.fn().mockResolvedValue({ ok: false });

afterEach(() => {
  vi.restoreAllMocks();
});

describe('App', () => {
  it('zobrazí predvolené meno keď config.json nie je dostupný', async () => {
    global.fetch = mockFetchFail();

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('heading')).toHaveTextContent('Ahoj, Jožko Mrkvička!');
    });
  });

  it('zobrazí meno z config.json keď je dostupný', async () => {
    global.fetch = mockFetch({ attendeeName: 'Jana Nováková' });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('heading')).toHaveTextContent('Ahoj, Jana Nováková!');
    });
  });

  it('ignoruje attendeeName ak nie je string', async () => {
    global.fetch = mockFetch({ attendeeName: 42 });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('heading')).toHaveTextContent('Ahoj, Jožko Mrkvička!');
    });
  });

  it('ignoruje attendeeName ak je prázdny string po trimmovaní', async () => {
    global.fetch = mockFetch({ attendeeName: '   ' });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('heading')).toHaveTextContent('Ahoj, Jožko Mrkvička!');
    });
  });

  it('zobrazí zdroj config.json po načítaní mena', async () => {
    global.fetch = mockFetch({ attendeeName: 'Peter Novák' });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText(/Súčasný zdroj: config\.json/)).toBeInTheDocument();
    });
  });
});
