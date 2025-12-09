# BIOS Update Before Installation

_Created: 2025-03-01T20:56:52+00:00_

**user:**

The instructions say to do a full bios update before installing. I hooked my computer back up but I have not powered it on yet. What are my steps to ensure bios update prior to installation

**assistant:**

Before you proceed with the BIOS update, let’s go through the correct sequence to ensure it is done safely and efficiently. Here’s your step-by-step process:

---

### **Step 1: Prepare for the BIOS Update**
1. **Verify Your Motherboard Model & Current BIOS Version**
   - Power on your PC and immediately enter the BIOS by pressing `DEL` or `F2` (common keys, but check your motherboard manual).
   - Locate the current BIOS version (usually displayed on the main BIOS screen).
   - Write it down for reference.

2. **Download the Latest BIOS Update**
   - On a separate device (or your PC once it's online), go to your **motherboard manufacturer's website**.
   - Locate your exact motherboard model.
   - Navigate to the **Support** or **Downloads** section and find the latest **BIOS update**.
   - Download the BIOS file and any update utility required.

3. **Prepare a USB Drive**
   - Use a **small USB flash drive** (preferably 16GB or less, formatted as **FAT32**).
   - Copy the downloaded BIOS file to the USB.
   - If needed, rename the BIOS file (some manufacturers require a specific name like `BIOS.ROM` or `XXXX.BIN`—check the update instructions).

---

### **Step 2: Perform the BIOS Update**
1. **Enter BIOS**
   - Restart your PC and re-enter BIOS using `DEL` or `F2`.

2. **Locate the BIOS Update Tool**
   - Look for a utility named **Q-Flash, EZ Flash, Flash BIOS, or M-Flash** (varies by manufacturer).
   - Select the update option.

3. **Update BIOS**
   - Insert the USB flash drive.
   - Select the BIOS file from the USB.
   - Confirm the update and **DO NOT power off your PC** during the process.
   - Let the system complete the update (it may restart multiple times).

---

### **Step 3: Post-Update Checks**
1. **Reset BIOS Settings (if needed)**
   - After updating, your BIOS may reset to default settings.
   - If you had specific configurations (XMP profiles, boot settings, etc.), reapply them.

2. **Verify the BIOS Version**
   - Enter BIOS again and confirm the version is updated.

3. **Proceed with the Installation**
   - If everything looks good, **power off the PC and proceed with the hardware installation**.

---

Let me know if you need specific details for your motherboard model!

**user:**


I downloaded the BIOS it's on a flash drive but it doesn't show up when I plug it in here

**assistant:**

It looks like your BIOS update file isn't being recognized in the ASUS EZ Flash 3 Utility. Here’s how to troubleshoot and resolve the issue:

---

### **Step 1: Ensure the Flash Drive is Formatted Correctly**
1. Plug the flash drive into another PC.
2. Open **File Explorer** → **Right-click the USB drive** → **Properties**.
3. Check the **File System**:
   - It **must be formatted as FAT32**.
   - If it’s NTFS or exFAT, reformat it:
     - **Right-click the USB drive** → **Format** → **Select FAT32** → **Start**.

---

### **Step 2: Rename the BIOS File (If Required)**
1. Go to ASUS’s website for your **PRIME A320M-K** motherboard.
2. Look for BIOS update instructions—some ASUS boards require the BIOS file to be renamed.
   - The file might need to be named **A320MK.CAP** (or similar).
   - If there’s a **BIOSRenamer.exe** in the downloaded ZIP file, run it to rename the BIOS file correctly.

---

### **Step 3: Place the BIOS File in the Root Directory**
1. **Extract the BIOS file** from the downloaded ZIP (if you haven’t already).
2. Copy **only the .CAP BIOS file** to the **root directory** of the USB drive.
   - The file should **not** be inside any folders.

---

### **Step 4: Try a Different USB Port**
- Some motherboards only recognize BIOS update files from **specific USB ports**.
- Use a **USB 2.0 port** (usually black, not blue).
- Try different USB slots on the **rear I/O panel** instead of the front panel ports.

---

### **Step 5: Restart and Try Again**
1. Restart your PC and enter the BIOS (`DEL` key or `F2`).
2. Go to **Advanced Mode** → **Tool** → **EZ Flash 3 Utility**.
3. Check if the USB drive now appears with the BIOS file.

---

### **Final Step: Use BIOS Flashback (If Available)**
- If your motherboard has a **BIOS Flashback** feature, you can update the BIOS without even booting into the BIOS.
- Look for a **BIOS Flashback button** on the rear I/O panel and follow ASUS’s instructions.

---

Try these steps and let me know what happens!

**user:**

I had extracted them and moved both files over to the thumb drive. I will have to restart my computer to check to formatting on the drive. I only have the one machine here

**assistant:**

Understood! Since you only have the one machine, follow this plan to check and fix any potential issues efficiently:

### **1. Restart & Enter BIOS Again**
- Try plugging the USB drive into a **different rear USB port** (preferably USB 2.0).
- Restart the computer and re-enter BIOS (`DEL` or `F2` key).
- Check if the BIOS update file appears now in the **EZ Flash 3 Utility**.

If it still doesn’t show up, proceed to the next step.

---

### **2. Reformat the USB Drive from the BIOS (If Possible)**
- Some ASUS motherboards allow you to format the USB drive directly from the BIOS.
- If you see an option to format it as **FAT32**, use it.
- Then, restart and transfer the BIOS file again.

---

### **3. Use the UEFI Shell to Check USB**
- If the USB still isn’t recognized, check the **UEFI Boot Options**:
  - Go to **Boot** settings in BIOS.
  - If your USB drive appears there but isn’t detected in EZ Flash 3, the formatting is likely wrong.

---

### **4. Quick Format & Reinstall BIOS File**
Since you only have this one machine:
- Restart the PC and let it boot into your OS.
- Format the USB to **FAT32** (this will erase everything on it).
- Re-download and **extract** the BIOS update files again.
- Move **only the .CAP file** to the USB root directory.
- Plug the USB back in and retry **EZ Flash 3**.

---

### **5. Alternative USB Drive**
- If the USB drive still isn’t recognized, the issue may be the drive itself.
- If you have another USB drive available, try using that.

---

Let me know how it goes after the restart. If you get stuck at any step, I’ll walk you through it.

**user:**


It showed up after I deleted the rename file and left only the cap file. However I got this pop up now and I have no idea how to backup my BitLocker recovery key and suspendicular encryption and operating system before updating bios. I'm assuming I select yes to go back and change that or no to pursue without doing it

**assistant:**

This warning means your system drive is encrypted with **BitLocker**, and updating the BIOS could trigger a recovery request, requiring your **BitLocker recovery key** to unlock the drive after the update. If you don't have the key, you could get locked out of your system.

---

### **Steps to Back Up Your BitLocker Recovery Key & Suspend BitLocker**
1. **Press "Yes" to go back** and boot into Windows.
2. **Find Your BitLocker Recovery Key**:
   - Open **Command Prompt as Administrator** (`Win + X → Command Prompt (Admin)`)
   - Run this command:  
     ```
     manage-bde -protectors C: -get
     ```
   - This will display the **Recovery Key ID and Key**. Write it down or save it somewhere safe.
   - Alternatively, your recovery key might be:
     - Saved in your Microsoft Account: [https://account.microsoft.com/devices/recoverykey](https://account.microsoft.com/devices/recoverykey)
     - Stored as a file on another drive.
     - Printed on paper if you saved it earlier.

3. **Suspend BitLocker** (Prevents Recovery Prompt After BIOS Update):
   - Open **Command Prompt as Administrator** and run:
     ```
     manage-bde -protectors C: -disable
     ```
   - OR use **Control Panel**:
     - **Go to Start → Type "BitLocker" → Manage BitLocker**.
     - Click **Suspend protection** (this is temporary and prevents issues after BIOS updates).

4. **Proceed with the BIOS Update**:
   - Restart and go back to BIOS.
   - Re-enter **EZ Flash 3** and select the BIOS update file again.
   - This time, **select "No"** on the BitLocker warning (since you've already backed up and suspended it).

5. **Re-enable BitLocker After BIOS Update**:
   - Boot into Windows and run:
     ```
     manage-bde -protectors C: -enable
     ```
   - OR go back to **Control Panel → Manage BitLocker → Resume protection**.

---

### **What Happens if You Skip This?**
If you update the BIOS without suspending BitLocker, your system **might** prompt you for the BitLocker recovery key on the next boot. If you **don't have the key**, you won’t be able to access your system.

Let me know if you need guidance on any of these steps!

**assistant:**

Your system is **not** encrypted with BitLocker. The errors confirm that:

1. **No key protectors are found** → Meaning BitLocker is **not enabled** on your system.
2. **The drive is not encrypted** → Windows confirms that **BitLocker is not active**.

This means you can safely proceed with the BIOS update without worrying about being locked out. 

### **Next Step: Continue BIOS Update**
- Go back to BIOS and re-enter the **EZ Flash 3 Utility**.
- When the **BitLocker warning pops up again**, select **"No"** to continue with the update.
- Let the BIOS update process complete.

Once done, your system should restart normally. Let me know if you run into anything unexpected! 🚀

**user:**

Microsoft Windows [Version 10.0.26100.3194]
(c) Microsoft Corporation. All rights reserved.

C:\Users\17602>manage-bde -protectors C: -get
BitLocker Drive Encryption: Configuration Tool version 10.0.26100
Copyright (C) 2013 Microsoft Corporation. All rights reserved.

Volume C: []
All Key Protectors

ERROR: No key protectors found.

C:\Users\17602>manage-bde -protectors C: -get
BitLocker Drive Encryption: Configuration Tool version 10.0.26100
Copyright (C) 2013 Microsoft Corporation. All rights reserved.

Volume C: []
All Key Protectors

ERROR: No key protectors found.

C:\Users\17602>manage-bde -protectors C: -disable
BitLocker Drive Encryption: Configuration Tool version 10.0.26100
Copyright (C) 2013 Microsoft Corporation. All rights reserved.

ERROR: An error occurred (code 0x8031005a):
This version of Windows does not support this feature of BitLocker Drive Encryption. To use this feature, upgrade the operating system.

C:\Users\17602>manage-bde -protectors C: -enable
BitLocker Drive Encryption: Configuration Tool version 10.0.26100
Copyright (C) 2013 Microsoft Corporation. All rights reserved.

ERROR: An error occurred (code 0x80310001):
This drive is not encrypted.

C:\Users\17602>

