import './globals.css';
import Workspace from './Workspace';

export const metadata = {
  title: 'StockPilot | Item forecast',
  description: 'Train a local XGBoost sales forecast for one item across your stores.',
};

export default function RootLayout({ children }) {
  return <html lang="en"><body><Workspace>{children}</Workspace></body></html>;
}
