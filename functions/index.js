const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");

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
