/**
 * Test-only stubs for shadcn/ui primitives and @/lib/utils.
 *
 * These are NOT part of the copy-paste template — they exist solely so the
 * vitest render test for LoginCard can run inside the canon repo, where the
 * real `@/components/ui/*` and `@/lib/utils` modules do not exist (they resolve
 * in the target project). vitest.config.ts aliases the bare imports here.
 */
import * as React from "react";

// --- @/lib/utils ---------------------------------------------------------
export function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(" ");
}

// --- @/components/ui/button ---------------------------------------------
export const Button = React.forwardRef<
  HTMLButtonElement,
  React.ButtonHTMLAttributes<HTMLButtonElement>
>(function Button(props, ref) {
  return <button ref={ref} {...props} />;
});

// --- @/components/ui/input ----------------------------------------------
export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(function Input(props, ref) {
  return <input ref={ref} {...props} />;
});

// --- @/components/ui/dropdown-menu --------------------------------------
export function DropdownMenu({ children }: { children: React.ReactNode }) {
  return <div data-stub="dropdown-menu">{children}</div>;
}
export function DropdownMenuTrigger({
  children,
  ...rest
}: React.HTMLAttributes<HTMLButtonElement>) {
  return (
    <button type="button" {...rest}>
      {children}
    </button>
  );
}
export function DropdownMenuContent({
  children,
}: {
  children: React.ReactNode;
  align?: string;
}) {
  return <div data-stub="dropdown-content">{children}</div>;
}
export function DropdownMenuItem({
  children,
  onSelect,
  ...rest
}: React.HTMLAttributes<HTMLDivElement> & { onSelect?: () => void }) {
  return (
    <div role="menuitem" onClick={() => onSelect?.()} {...rest}>
      {children}
    </div>
  );
}

// --- lucide-react icons --------------------------------------------------
type IconProps = React.SVGProps<SVGSVGElement>;
const makeIcon = (name: string) =>
  function Icon(props: IconProps) {
    return <svg data-icon={name} {...props} />;
  };
export const ChevronDown = makeIcon("chevron-down");
export const MessageCircle = makeIcon("message-circle");
export const Mail = makeIcon("mail");
