import React, { useState } from 'react';
import { SecuritySanitizer } from '@/lib/security/sanitizer';

interface SecureInputProps {
  value: string;
  onChange: (value: string) => void;
  maxLength?: number;
  placeholder?: string;
  type?: 'text' | 'email' | 'password';
}

export const SecureInput: React.FC<SecureInputProps> = ({
  value,
  onChange,
  maxLength = 255,
  placeholder,
  type = 'text'
}) => {
  const [error, setError] = useState<string>('');

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const sanitized = SecuritySanitizer.validateInput(e.target.value, maxLength);
      onChange(sanitized);
      setError('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid input');
    }
  };

  return (
    <div className="space-y-1">
      <input
        type={type}
        value={value}
        onChange={handleChange}
        placeholder={placeholder}
        maxLength={maxLength}
        className={`w-full px-3 py-2 border rounded-md ${
          error ? 'border-red-500' : 'border-gray-300'
        }`}
      />
      {error && (
        <p className="text-sm text-red-500">{error}</p>
      )}
    </div>
  );
};