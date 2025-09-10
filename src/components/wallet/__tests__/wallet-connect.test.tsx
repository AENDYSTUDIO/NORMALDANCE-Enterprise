import { render, screen, fireEvent } from '@testing-library/react';
import { WalletConnect } from '../wallet-connect';

// Mock Solana wallet
jest.mock('@solana/wallet-adapter-react', () => ({
  useWallet: () => ({
    connected: false,
    connecting: false,
    connect: jest.fn(),
    disconnect: jest.fn(),
    publicKey: null,
  }),
}));

describe('WalletConnect', () => {
  it('renders connect button when not connected', () => {
    render(<WalletConnect />);
    expect(screen.getByText(/connect/i)).toBeInTheDocument();
  });

  it('shows connecting state', () => {
    jest.doMock('@solana/wallet-adapter-react', () => ({
      useWallet: () => ({
        connected: false,
        connecting: true,
        connect: jest.fn(),
        disconnect: jest.fn(),
        publicKey: null,
      }),
    }));
    
    render(<WalletConnect />);
    expect(screen.getByText(/connecting/i)).toBeInTheDocument();
  });
});