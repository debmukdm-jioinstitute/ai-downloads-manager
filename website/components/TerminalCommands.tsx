"use client";

import { useState } from "react";

export const INSTALL_TERMINAL_LINES = [
  "xattr -dr com.apple.quarantine /Applications/Nest.app",
  "open /Applications/Nest.app",
] as const;

export function TerminalCommands({ id }: { id?: string }) {
  const [copied, setCopied] = useState(false);
  const text = INSTALL_TERMINAL_LINES.join("\n");

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      /* fallback: selection still works in the block */
    }
  }

  return (
    <div className="install-terminal-wrap">
      <div className="install-terminal-header">
        <span className="text-[12px] font-medium text-[#a1a1a6]">Terminal</span>
        <button type="button" className="install-terminal-copy" onClick={copy}>
          {copied ? "Copied" : "Copy both lines"}
        </button>
      </div>
      <pre id={id} className="install-terminal" tabIndex={0}>
        <code>
          {INSTALL_TERMINAL_LINES.map((line) => (
            <span key={line} className="install-terminal-line">
              <span className="prompt">$ </span>
              {line}
            </span>
          ))}
        </code>
      </pre>
    </div>
  );
}
