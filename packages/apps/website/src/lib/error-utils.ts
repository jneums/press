/**
 * Utility functions for handling and displaying errors
 */

export interface ParsedError {
  message: string;
  isAllowanceError: boolean;
  showGarageLink: boolean;
}

/**
 * Parse an error and determine if it's an allowance error that needs user action
 */
export function parseError(error: unknown): ParsedError {
  const errorMessage = error instanceof Error ? error.message : String(error);
  
  // Check if it's an insufficient allowance error
  const isAllowanceError = errorMessage.toLowerCase().includes('insufficient spending allowance') ||
                          errorMessage.toLowerCase().includes('insufficient allowance');
  
  return {
    message: errorMessage,
    isAllowanceError,
    showGarageLink: isAllowanceError,
  };
}

/**
 * Format an error message for display with actionable instructions
 */
export function formatErrorMessage(error: unknown): string {
  const parsed = parseError(error);
  
  if (parsed.isAllowanceError) {
    return `${parsed.message}\n\nGo to the Garage page to set up your spending allowance.`;
  }
  
  return parsed.message;
}
