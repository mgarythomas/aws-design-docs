import { twMerge } from 'tailwind-merge';

export const ErrorMessage = ({ message, className }: { message?: string, className?: string }) => {
  if (!message) return null;
  return <p className={twMerge("text-sm font-medium text-red-500 mt-1", className)}>{message}</p>;
};
