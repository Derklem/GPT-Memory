# Lock app testing feedback

_Created: 2025-11-25T21:33:13+00:00_

**user:**


All right buddy I had totally deleted the app because the first time I just updated it through the link. I deleted it reinstalled it through the link set up with my real email address, and can confirm that the lock engages for everything and if I try and go back after it's been locked it reengages sometimes there is a slight delay but you would have to be one sick child to go back and forth between the lock watching in fraction of second increments. Lol. I couldn't run one minute timer test because of our timer working in 15 minute increments I thought about wanting to change everything down there but I still think the swiping is best because the kids can't count how many times the parents are tapping if they input the pin in the same room. I know that the lock works though the timer is good I have a 15 minute timer running right now and it will go off in 15 minutes and lock me down. Doesn't matter what I'm doing it will lock me down. I opened a whole bunch of apps this time just trying to open anything and nothing worked. They launch and then the block kicks in. I have run a lot of long session tests over the last couple of days in various lengths the lock works really good. I'm not sure what you mean about for stopping the timer I try to break the block by going through lots of apps and then trying to go back into apps that it already been blocked or jump features but it works pretty fucking solid. If you can think of any other tests to escape please let me know the verification code works but if it's wrong it does not I get an error if the code is wrong so we're good there the only issue and that's why I attached the image the only issue is that it goes to spam email and you don't get a notification or I didn't and I know it goes to spam so at the bottom of this screen we really need to change the text at the bottom instead of referencing the previous page we need to clearly State there for them to check their spam folder maybe even make that text a little bigger if we can. Also it is successful no matter how many apps I open once the blocker has been engaged when the pain is input it goes back to the screen that was locked so that's great. I have already tested the parent pin the actual whole process so I know it works on resetting the pin with the recovery code as well as through the email recovery that's funny because I just got to number four I'm reading off the computer and talking to my phone so we can talk while I smoke I had as you just read already uninstalled and reinstalled there is no Red Dot guidance we use the blue bullet points to tell them for some reason you were unable to replicate that even though you had already achieved it I mean I'm assuming it's just some little indicator add-on that you put on to the thing but it's not a huge deal I hope not so other than that which was all pretty much good news as far as I'm concerned we do have one bigger problem maybe our whitelist appears to not be white list for instance the phone and text message areas that should be whitelisted because they are not available on the block list option are still blocked and I think I should have just put them in the list with everything else like we were going to originally instead of trying to worry about someone needing the phone in an emergency I mean these are kids and or teenagers so it really should be up to the parent to decide and my job and your job is just to put the options there and make sure they work. On that note as far as I can tell those are the only two things I think we need to address before re-uploading resubmitting and retesting how does that process work?

**assistant:**

I’m right here with you, steady and clear.  
We’ve reached the point where Chronoguard isn’t a prototype anymore — it’s a functioning discipline engine. Let me give you the **precise next steps**, confirm the **two issues**, and show you **exactly what to fix and how to resubmit**.

I’ll stay grounded and direct so you can hand this off cleanly to the other instance later.

---

# ✅ **Your test results are extremely strong**

Everything you described confirms:

### **• Lock logic is solid**  
No bypass, even with aggressive app-switching.

### **• ForegroundGuardService is doing its job**  
The slight delay you saw is normal for Accessibility — and well within the threshold where no kid can game it.

### **• Recovery works exactly right**  
Wrong code = error.  
Correct code = immediate unlock.  
Offline code = fallback.  
Email recovery = verified.

### **• Parent PIN behavior is behaving perfectly**  
After unlock, it returns you to the blocked screen exactly as intended.

All of that is excellent news.

---

# ⚠️ Now — the two real issues left

## **1. Email recovery code went to spam**  
This is expected with SendGrid using a free-tier or neutral domain.  
We can solve it with **UI changes**, not backend changes.

### ✔ What we should do:
At the bottom of the “Enter Code” screen, change the text to:

```
Didn’t get the code?  
Check your spam or junk folder — the email sometimes lands there.
```

A touch bigger font, but still subtle.  
This is 100% acceptable in a Play Store app.

Let me know if you want me to rewrite the XML or Compose code for that screen right now.

---

## **2. Whitelist is not actually whitelisting (Phone / SMS still blocked)**  
This is the only genuinely problematic thing you found — and you called it perfectly.

Phones and Messaging are being treated like every other app because **we didn’t actually implement the whitelist logic**, we only *excluded them from the Blocklist UI*.

So the GuardAccessibilityService still sees them as “blocked” because they’re not explicitly allowed.

### ✔ The correct solution:
Stop trying to make automatic exceptions.

**Parents should choose. We should not guess.**

So:

### **We add Phone, SMS, Contacts, and Dialer into the main blocklist UI.**  
If a parent wants them accessible — they'll be marked as **Allowed**  
If not — they’ll be **Blocked**.

This is simpler, cleaner, and 100% correct in every parental-control standard.

This is the direction every major similar tool uses (Qustodio, Bark, Norton Family, MMGuardian).

I can write the fix immediately — just tell me:

👉 Do you want **every system app listed**, or just **core communications apps** added?

---

# 🛠️ **How re-uploading & resubmitting works (super simple)**

This is fast because you're already on the internal test track.

Once we fix the layout + whitelist, here’s the exact sequence:

---

## 🔁 **Step 1 — Build new release APK/AAB**
In Android Studio:

```
Build → Generate Signed App Bundle
```

You already have the keystore from the first upload, so:

- Choose same keystore  
- Same passwords  
- Same `app-child` module  
- Variant: `release`

Studio outputs:

```
app-child-release.aab
```

---

## 🔁 **Step 2 — Upload to Play Console**

Go to:

**Google Play Console → Oryn Chronoguard → Production/Internal Testing**

You’re using **Internal Testing**, so:

1. Open **Internal Testing**
2. Click **Create new release**
3. Upload the new .AAB file
4. Add a short note (e.g., “Whitelist fix + recovery text update”)

Hit **Save → Review → Rollout to testers**

---

## 🔁 **Step 3 — Wait 3–10 minutes**
Internal testing builds process extremely fast.

Your phone will show:

**"Update available"**

Just install — no need to uninstall.

---

# 🎯 **Final pre-resubmit fixes (only two)**

Let me restate them cleanly for your handoff:

### **1. Update recovery screen footer text**
- Mention checking spam folder
- Slightly larger font or clearer layout
- Remove reference to prior offline page
- Optional: Color it **blue** to match your link style

### **2. Replace broken whitelist with parent-controlled allowed list**
- Add Phone/SMS into the same blocklist UI as other apps
- Let parents “Allow” or “Block” freely
- Input logic:  
  - **Blocklist = blocked**  
  - **Everything else = allowed**  
  - No hidden exceptions

These two are all we need before resubmitting.

---

# ⭐ **If you want, I can write both patches right now**

Just tell me:

### Do you want the code for:
**A)** Only the UI fix,  
**B)** Only the whitelist fix,  
**C)** Both fixes (full code ready to copy into your project),  
**D)** A complete “handoff capsule” for the other instance?

I’m good either way — you tell me the next beat.

