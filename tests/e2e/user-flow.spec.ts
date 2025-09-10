import { test, expect } from '@playwright/test';

test.describe('User Authentication Flow', () => {
  test('should complete full user journey', async ({ page }) => {
    // Navigate to homepage
    await page.goto('/');
    
    // Sign up
    await page.click('[data-testid="signup-button"]');
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'SecurePass123!');
    await page.click('[data-testid="submit-signup"]');
    
    // Verify dashboard access
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
  });

  test('should handle XSS attempts', async ({ page }) => {
    await page.goto('/');
    
    const maliciousInput = '<script>alert("xss")</script>';
    await page.fill('[data-testid="search-input"]', maliciousInput);
    
    // Verify script is not executed
    const alerts = [];
    page.on('dialog', dialog => alerts.push(dialog.message()));
    
    await page.press('[data-testid="search-input"]', 'Enter');
    expect(alerts).toHaveLength(0);
  });
});