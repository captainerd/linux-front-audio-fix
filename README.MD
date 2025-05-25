# Linux Front Headphones Fix (Zorin, Mint, Ubuntu, etc.)

### Fix "Front Headphones Not Detected" on Linux Distros

If your **front panel headphones aren't showing up** or **plugging them in does nothing**, especially on Linux distros like **Zorin OS**, **Linux Mint**, or **Ubuntu**, this tiny utility is for you.
 

This script creates a **virtual audio output** named "Headphones" that always appears in your Sound Settings. It auto-switches to your real audio card when selected. Ideal for desktops or motherboards where the **front audio jack detection (fsense)** is broken, missing, or simply not supported.

---

### ✅ What It Does

* Adds a dummy "Headphones" audio output
* Automatically switches the real output to front headphones when selected
* Makes your front jack usable even if the detection mechanism is busted

---

### 💡 How to Use

**Option A: Install the .deb file**

1. Go to the [Releases](https://github.com/captainerd/linux-front-audio-fix/releases) page
2. Download the latest `.deb` file
3. Install it via GUI or run:

   ```bash
   sudo dpkg -i linux-headphones_1_all.deb
   ```

**Option B: Build it yourself**

1. Clone the repo:

   ```bash
   git clone https://github.com/youruser/linux-front-audio-fix.git
   cd linux-front-audio-fix
   ```
2. Build the .deb file:

   ```bash
   ./build-deb.sh
   ```
3. Install it:

   ```bash
   sudo dpkg -i linux-headphones_1_all.deb
   ```

---

### 🔍 Why Your Headphones Might Not Work (The Nerd Stuff)

Modern audio chips (Intel HD Audio spec) use **jack sensing** — the front panel audio jack reports when something is plugged in via special "fsense" return signals (usually pins 6 and 10 on the motherboard header).
 ![HD Audio Pinout](https://i.imgur.com/vCbO6Av.png)
Older cases using the **AC'97 spec** might not even connect those fsense pins, or the cable is just plain missing. Worse, the **jack hole itself might be broken**, and the small switch inside isn't getting shorted by the jack anymore.

On Windows, you often get registry-level overrides, vendor tools, or Realtek software. On Linux? You're expected to:

* Use `pavucontrol` to route things manually every time
* Or go full hardware hacker and short pins 6 and 10 on the header

This script gives you an **automatic, software workaround** instead.

---

### 📦 What You Get

* Systemd service that runs on boot
* Virtual sink created using PulseAudio
* Auto-switching logic if you select the "Headphones" device

---

### 🧹 Uninstall

To remove everything cleanly:

```bash
sudo apt remove linux-headphones
```

It'll also disable and remove the systemd service.

---

### 💬 Feedback / Issues

Found a bug? Missing a use case? Open an issue on the [GitHub repo](https://github.com/captainerd/linux-front-audio-fix).

---

**This exists because fsense sucks and Linux never quite solved it.**

