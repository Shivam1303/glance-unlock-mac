# Glance Unlock user guide

## Before you begin

Glance Unlock is an offline privacy-layer prototype. It can hide selected apps and ask for face-and-blink verification before restoring them, but it does not lock your Mac, replace the macOS login window, unlock FileVault, or provide Face ID-level security. Quitting Glance disables app protection.

Use it only on your own Mac in a private setting. Glance never reads or stores your Mac password. The optional **Use Touch ID or Password** action is presented and handled entirely by macOS.

## Start the app

1. Open `GlanceUnlock/GlanceUnlock.xcodeproj` in Xcode 26.6.
2. Select the **GlanceUnlock** scheme and **My Mac** as the run destination.
3. Choose Run.

After initial setup, Glance can remain in the menu bar without keeping its main window open. Use the menu-bar face icon to open Glance, manage protected apps, pause or resume protection, or quit.

## Allow camera access

The app first explains that processing happens locally and that no camera images are saved. Choose **Allow camera access** when you are ready.

If access is denied, select **Open Camera Privacy settings** in the app. Enable Glance Unlock under System Settings → Privacy & Security → Camera, then return to the app.

## Enrol your face

1. Select **Enrol your face**.
2. Put only one face in the guide and use normal, even room lighting.
3. Hold still briefly for each sample. Between samples, look forward and make small left/right head turns.
4. Continue until the app reports that all five samples are saved.

The app stores only derived Vision feature representations in this Mac’s Keychain. Team-signed builds use the device-only Data Protection Keychain; local “Sign to Run Locally” builds use the encrypted macOS login Keychain because they have no Keychain access-group entitlement. It discards camera frames after local processing and does not display a Keychain authentication prompt.

## Protect applications

1. From the home screen, select **Manage Protected Apps**.
2. Turn on **Protection active**.
3. Enable the switch beside each application you want Glance to cover.
4. Optionally enable **Launch at Login**. If macOS requests approval, use **Open Login Items Settings** and allow Glance under System Settings → General → Login Items.
5. Close the main window if desired. Do not choose **Quit Glance** from the menu-bar control; closing the window keeps protection running, while quitting disables it.
6. Switch to a selected app.
7. Glance covers the selected app while it checks your face. Follow the notch instructions and blink when requested.
8. After a successful match, the gate disappears. Switching to a different app relocks it.

At every gate, **Use Touch ID or Password** invokes the standard macOS device-owner authentication dialog. Depending on the Mac and its configuration, macOS can use Touch ID, Apple Watch, or the account password. The gate has no cancel/back action and cannot be dismissed with Escape or Close Window. Cancelling the macOS dialog returns to the still-locked gate and resumes face verification.

This feature works only while Glance is running. It is a privacy convenience, not a tamper-resistant lock: quitting Glance or otherwise bypassing cooperative app hiding disables the protection.

## Try the face-check demo

1. From the home screen, select **Try Face Check**.
2. The app opens its simulated full-screen lock view. This is not the real macOS lock screen.
3. Look at the camera. After the face is recognized consistently, the app asks you to blink once.
4. Make a natural blink: eyes open, then closed, then open again. Both matching and the blink are required before the view dismisses.

Choose **Exit safe lock** at any point to leave the simulation.

## Reset or re-enrol

Select **Reset face profile** on the home screen to permanently remove the Keychain item. You can then enrol again.

## Calibration and responsible testing

The debug build includes a **Developer tuning** control for the provisional local match-distance threshold. Lower values are more conservative. Adjust it only after testing locally in different lighting; prefer rejecting a valid attempt over accepting an uncertain one.

For manual validation, record only pass/fail outcomes and broad distance ranges. Do not save camera images.

- Test yourself in daylight and indoor lighting, with slight left/right angles.
- Test no face, two faces, a covered camera, and camera permission recovery.
- Test simple spoof attempts such as a printed photo and a phone-displayed photo.

Even if these checks work, replayed video, high-quality displays, and sophisticated masks may still defeat this prototype.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| Camera access is off | Use **Open Camera Privacy settings**, enable access, then relaunch or return to enrolment. |
| “One person at a time” | Ensure only one face is visible to the camera. |
| “Move a little closer” or “Center your face” | Sit about 45–75 cm away and align your face to the guide. |
| “Improve lighting and hold still” | Use brighter, more even lighting and keep still briefly. |
| “Not recognized” | Re-enrol with varied samples. In a debug build, review the conservative developer threshold. |
| A protected app did not prompt | Confirm **Protection active** is enabled, the app’s switch is on, and Glance is still running. Switch to another app and back again. |
| You do not want to use face recognition | Choose **Use Touch ID or Password** in the app gate. The dialog is controlled by macOS. |
| The app gate remains visible | Complete face-and-blink verification or choose **Use Touch ID or Password**. Cancelling macOS authentication does not dismiss the gate. |
| Face Check is still visible | Choose **Exit safe lock**; closing the app also exits the simulation. |
