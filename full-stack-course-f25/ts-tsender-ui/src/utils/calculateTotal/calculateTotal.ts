export function calculateTotal(amounts: string): number {
    return amounts
      .split(/[\n,]+/)
      .map(amt => amt.trim())
      .filter(amt => amt !== "")
      .map(amt => parseFloat(amt))
      .filter(n => !isNaN(n))
      .reduce((sum, n) => sum + n, 0);
  }
