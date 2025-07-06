// components/Header.tsx

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { FaGithub } from "react-icons/fa";
import Image from "next/image";

export default function Header() {
  return (
    <header className="w-full flex items-center justify-between p-4 border-b bg-red-500 border-gray-200">
      <div className="flex items-center space-x-4">
        {/* Logo or title */}
        <Image src="/favicon.ico" alt="Logo" width={24} height={24} />
        <span className="text-xl font-bold">tsender</span>
      </div>

      <div className="flex items-center space-x-4">
        <a
          href="https://github.com/yotov721"
          target="_blank"
          rel="noopener noreferrer"
          className="text-gray-700 hover:text-black"
        >
          <FaGithub size={24} />
        </a>
        <ConnectButton />
      </div>
    </header>
  );
}
