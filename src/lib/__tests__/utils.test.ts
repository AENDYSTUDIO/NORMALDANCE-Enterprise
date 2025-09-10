import { cn } from '../utils';

describe('utils', () => {
  it('combines class names correctly', () => {
    expect(cn('class1', 'class2')).toBe('class1 class2');
  });

  it('handles conditional classes', () => {
    expect(cn('base', true && 'conditional')).toBe('base conditional');
    expect(cn('base', false && 'conditional')).toBe('base');
  });

  it('removes duplicates', () => {
    expect(cn('class1', 'class1')).toBe('class1');
  });
});