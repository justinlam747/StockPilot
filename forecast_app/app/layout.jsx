import './globals.css';

export const metadata = {
  title: 'StockPilot | Item forecast',
  description: 'Train a local XGBoost sales forecast for one item across your stores.',
};

export default function RootLayout({ children }) {
  return <html lang="en"><body>{children}</body></html>;
}
