const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();

exports.createRazorpayOrder = onCall({ invoker: "public" }, async (request) => {
    const { amount, receipt } = request.data;

    if (!request.auth) {
        throw new HttpsError("failed-precondition", "User must be authenticated.");
    }

    if (!amount || amount < 1) {
        throw new HttpsError("invalid-argument", "Amount must be at least INR 1.");
    }

    const instance = new Razorpay({
        key_id: process.env.RAZORPAY_KEY_ID,
        key_secret: process.env.RAZORPAY_KEY_SECRET,
    });

    const options = {
        amount: amount * 100, // amount in the smallest currency unit
        currency: "INR",
        receipt: receipt || `receipt_${Date.now()}`
    };

    try {
        const order = await instance.orders.create(options);
        return { orderId: order.id, amount: order.amount, currency: order.currency };
    } catch (error) {
        console.error("Error creating Razorpay order:", error);
        throw new HttpsError("internal", "Failed to create Razorpay order.");
    }
});


exports.verifyPaymentSignature = onCall({ invoker: "public" }, async (request) => {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, bookingId } = request.data;

    if (!request.auth) {
        throw new HttpsError("failed-precondition", "User must be authenticated.");
    }

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
        throw new HttpsError("invalid-argument", "Missing payment verification parameters.");
    }

    const secret = process.env.RAZORPAY_KEY_SECRET;

    if (!secret) {
        console.error("RAZORPAY_KEY_SECRET is not set");
        throw new HttpsError("internal", "Server misconfiguration.");
    }

    const body = razorpay_order_id + "|" + razorpay_payment_id;

    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(body.toString())
        .digest('hex');

    const isAuthentic = expectedSignature === razorpay_signature;

    if (isAuthentic) {
        if (bookingId) {
            try {
                console.log(`Payment authentic. Updating booking ${bookingId}`);
                const db = admin.firestore();
                await db.doc(`bookings/${bookingId}`).set({
                    paymentStatus: 'successful',
                    razorpayOrderId: razorpay_order_id,
                    razorpayPaymentId: razorpay_payment_id,
                    paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true });
                console.log(`Document successfully updated for ${bookingId}`);
            } catch (err) {
                console.error("Error updating booking status", err);
            }
        }

        return { success: true };
    } else {
        throw new HttpsError("invalid-argument", "Invalid payment signature.");
    }
});

exports.requestAdminAccess = onCall({ invoker: "public" }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { name, email } = request.data;
    const uid = request.auth.uid;

    const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS
        }
    });

    const projectId = process.env.GCLOUD_PROJECT || "rentra-64f73"; // Note: Replace with actual project ID if env missing
    const approveUrl = `https://us-central1-${projectId}.cloudfunctions.net/approveAdminAccess?uid=${uid}`;

    const mailOptions = {
        from: process.env.EMAIL_USER,
        to: "amitkumarstm1507@gmail.com",
        subject: "New Admin Request for Rentra App",
        html: `
            <h2>New Admin Request</h2>
            <p>User with email: <strong>${email}</strong></p>
            <p>Name: <strong>${name}</strong></p>
            <p>is requesting to be the admin.</p>
            <br/>
            <p>Click the button below if you want to allow this request:</p>
            <a href="${approveUrl}" style="padding: 10px 20px; background-color: #28a745; color: white; text-decoration: none; border-radius: 5px; display: inline-block;">Yes</a>
            <br/><br/>
            <p>If you don't allow, then simply ignore this email.</p>
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        return { success: true, message: "Request sent successfully." };
    } catch (error) {
        console.error("Error sending email:", error);
        throw new HttpsError("internal", "Failed to send request email.");
    }
});

exports.approveAdminAccess = onRequest(async (req, res) => {
    const uid = req.query.uid;

    if (!uid) {
        return res.status(400).send("<h1>Error</h1><p>Missing user ID in the request.</p>");
    }

    try {
        const db = admin.firestore();
        await db.collection("users").doc(uid).set({ isAdmin: true }, { merge: true });

        res.send(`
            <html>
            <head><title>Success</title></head>
            <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
                <h1 style="color: #28a745;">Success!</h1>
                <p>The user has been successfully made an admin.</p>
            </body>
            </html>
        `);
    } catch (error) {
        console.error("Error making admin:", error);
        res.status(500).send("<h1>Error</h1><p>An error occurred while updating the database:<br/><code>" + (error.message || error.toString()) + "</code></p>");
    }
});
