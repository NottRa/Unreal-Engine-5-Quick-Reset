# Unreal Quick Reset

Unreal Engine has a frustrating limitation:  
when your project crashes (often after changing UPROPERTY/UCLASS, or corrupting Live Coding DLLs), the editor refuses to start until you manually:

1. Kill background UE processes,  
2. Delete `Intermediate` and Live Coding patch DLLs,  
3. Regenerate Visual Studio project files,  
4. Open the `.sln` yourself,  
5. Rebuild and relaunch Unreal.

**This script automates all of that in one double-click.**

---

## ✨ Features
- Detects your `.uproject` automatically (or lets you pick it).  
- Auto-detects your Unreal Engine installation (or lets you pick it).  
- Cleans Live Coding patch DLLs by default.  
- Optional full clean (also removes `Intermediate` and `Binaries`).  
- Regenerates Visual Studio project files.  
- Opens your `.sln` (using your system’s default handler — Visual Studio, Rider, etc).  
- Launches Unreal Editor automatically.  
- Detached launch: closing the script window does **not** close Unreal.

---

## 🚀 Usage
1. Download `UnrealQuickReset.cmd`.  
2. Place it either:  
   - In your project folder (next to `.uproject`), or  
   - Anywhere else (it will prompt you to pick a `.uproject`).  
3. Double-click it. That’s it.  

---

## ⚙️ Options
Inside the script you can tweak:

- `FULL_CLEAN=0` → change to `1` if you want it to remove `Intermediate` and `Binaries` as well.  
- `OPEN_SOLUTION=1` → opens your `.sln`.  
- `DIAG_MODE=0` → change to `1` if you want Unreal to run inline with logs visible in the same console.  

---

## 📌 Why does this exist?
Unreal Engine Live Coding often leaves broken patch DLLs behind, causing mysterious crashes like:


The **only fix** is manual cleanup. Doing that 10+ times a day kills productivity.  

This script makes the process **instant**. No more digging through `Intermediate`, no more right-click → regenerate project files. Just one click.

---

## ⚠️ Limitations
- Windows-only (uses `.cmd` + PowerShell).  
- Requires Unreal Engine 5.x installed.  
- Tested with Visual Studio but works with Rider/CLion if they’re your `.sln` handler.  
- Not an official Epic tool.  

---

## 💡 Credits
Created to save time for developers frustrated by Unreal’s rebuild cycle.  

