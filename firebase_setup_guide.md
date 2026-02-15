# Firebase Email Verification Setup

To fully enable the email verification features implemented in the app, please follow these steps in your Firebase Console:

## 1. Enable Email/Password Authentication
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your project **Rentra**.
3. Navigate to **Authentication** > **Sign-in method**.
4. Ensure the **Email/Password** provider is enabled.
5. (Optional) Disable "Email link (passwordless sign-in)" unless you are specifically using it. The current implementation relies on standard email/password signup.

## 2. Configure Verification Email Template
1. In the **Authentication** section, click on the **Templates** tab.
2. Select **Email address verification**.
3. Here you can customize:
   - **Sender name**: Change this to "Rentra Team" or your app's name.
   - **Reply-to**: Set a valid support email address.
   - **Subject**: e.g., "Verify your email for Rentra".
   - **Message**: You can customize the greeting, but **DO NOT** remove the `%LINK%` placeholder. This is where the verification URL will be inserted.
4. Click **Save** after making changes.

## 3. (Optional) Custom Action URL
If you want to redirect users to a specific web page or deep link back to the app after verification:
1. Go to **Authentication** > **Settings** (or the gear icon).
2. Look for **Authorized domains**. Ensure your domain is listed if you use a custom link.
3. For mobile app handling (Dynamic Links), you would need additional setup, but the standard Firebase action link works fine for simple verification (open in browser -> user returns to app manually).

## 4. Testing
1. Create a new account in the Rentra app with a real email address.
2. Check your inbox (and spam folder) for the verification email.
3. Click the link.
4. Return to the app. The floating banner should disappear (you might need to pull-to-refresh or restart the app if using the emulator, as the auth state needs to reload).
