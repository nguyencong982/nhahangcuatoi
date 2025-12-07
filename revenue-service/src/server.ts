import express, { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';

// ======================================================
// 🚀 KHỞI TẠO SERVER EXPRESS + FIREBASE ADMIN
// ======================================================
const app = express();
app.use(express.json());

// Khởi tạo Firebase Admin SDK
admin.initializeApp();
const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ======================================================
// 🔐 AUTH MIDDLEWARE (XÁC THỰC NGƯỜI DÙNG)
// ======================================================
interface AuthenticatedRequest extends Request {
    user?: admin.auth.DecodedIdToken;
}

const authenticateUser = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
        return res.status(401).send({ error: 'Unauthorized: Missing or invalid Bearer token.' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    if (!idToken) return res.status(401).send({ error: 'Unauthorized: Invalid Firebase ID Token format.' });

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken;
        next();
    } catch (error) {
        console.error("Token verification failed:", error);
        return res.status(401).send({ error: 'Unauthorized: Invalid Firebase ID Token.' });
    }
};

// ======================================================
// 📊 API DOANH THU (GIỮ NGUYÊN)
// ======================================================
interface RevenueRequestData {
    year: number;
    month: number;
    day?: number;
}

app.post('/api/v1/admin/revenue-report', authenticateUser, async (req: AuthenticatedRequest, res: Response) => {
    const userUid = req.user!.uid;
    const { year, month, day } = req.body as RevenueRequestData;

    try {
        const userDoc = await firestore.collection('users').doc(userUid).get();
        const userRole = userDoc.data()?.role || 'customer';
        if (userRole !== 'admin' && userRole !== 'superAdmin') {
            return res.status(403).send({ error: "Permission denied: Requires Admin role." });
        }
    } catch (error) {
        console.error("Lỗi kiểm tra vai trò:", error);
        return res.status(500).send({ error: "Internal error checking permissions." });
    }

    if (!year || !month) {
        return res.status(400).send({ error: 'Vui lòng cung cấp năm và tháng hợp lệ.' });
    }

    let startPeriod: Date;
    let endPeriod: Date;
    const jsMonth = month - 1;

    if (day) {
        startPeriod = new Date(year, jsMonth, day);
        endPeriod = new Date(year, jsMonth, day + 1);
    } else {
        startPeriod = new Date(year, jsMonth, 1);
        endPeriod = new Date(year, jsMonth + 1, 1);
    }

    const startTimestamp = admin.firestore.Timestamp.fromDate(startPeriod);
    const endTimestamp = admin.firestore.Timestamp.fromDate(endPeriod);

    try {
        const snapshot = await firestore.collection('orders')
            .where('status', '==', 'completed')
            .where('timestamp', '>=', startTimestamp)
            .where('timestamp', '<', endTimestamp)
            .orderBy('timestamp', 'desc')
            .get();

        let totalRevenue = 0.0;
        const transactionDetails: any[] = [];
        const dailyRevenueMap: { [day: number]: number } = {};

        snapshot.docs.forEach(doc => {
            const data = doc.data();
            const totalAmount = (data.totalAmount as number) || 0.0;
            const timestamp = (data.timestamp as admin.firestore.Timestamp).toDate();
            const dayOfMonth = timestamp.getDate();

            totalRevenue += totalAmount;
            dailyRevenueMap[dayOfMonth] = (dailyRevenueMap[dayOfMonth] || 0) + totalAmount;

            const itemsSummary = (data.items as any[] || [])
                .map(item => `${item.name} x${item.quantity}`)
                .join('\n');

            transactionDetails.push({
                id: doc.id,
                itemsSummary,
                totalAmount,
                timestamp: timestamp.toISOString(),
            });
        });

        res.status(200).send({
            totalRevenue,
            transactionDetails,
            dailyRevenueMap,
        });

    } catch (error) {
        console.error("Lỗi server khi truy vấn đơn hàng:", error);
        return res.status(500).send({ error: 'Lỗi server khi truy vấn đơn hàng.' });
    }
});


// ======================================================
// 💬 API CHAT SERVICE (ĐÃ SỬA LỖI LATENCY)
// ======================================================

// Gửi tin nhắn
app.post('/api/v1/chat/send', authenticateUser, async (req: AuthenticatedRequest, res: Response) => {
    try {
        // ✅ NHẬN THÊM customerUID và shipperUID
        const { chatId, message, customerId, shipperId, customerUID, shipperUID } = req.body;
        const senderId = req.user!.uid;

        // ✅ Bổ sung kiểm tra customerUID/shipperUID
        if (!chatId || !message || !customerId || !shipperId || !customerUID || !shipperUID) {
            console.error('🔴 Thiếu dữ liệu đầu vào: ', { chatId, message: message ? 'có' : 'không', customerId, shipperId, customerUID, shipperUID });
            return res.status(400).send({ error: 'Thiếu chatId, message, customerId, shipperId, customerUID, hoặc shipperUID' });
        }

        // 1. **(CẦN THIẾT):** BỔ SUNG LOGIC LẤY TÊN BẰNG ADMIN SDK
        let customerName = 'Khách hàng';
        let shipperName = 'Shipper';

        try {
            const [customerDoc, shipperDoc] = await Promise.all([
                firestore.collection('users').doc(customerId).get(),
                firestore.collection('users').doc(shipperId).get(),
            ]);

            customerName = customerDoc.data()?.name || customerName;
            shipperName = shipperDoc.data()?.name || shipperName;

            console.log(`Đã fetch tên. Customer: ${customerName}, Shipper: ${shipperName}`);
        } catch (fetchError) {
            console.error('🔴 Lỗi khi fetch tên người dùng:', fetchError);
            // Tiếp tục ngay cả khi lỗi fetch tên, để tin nhắn vẫn được gửi với tên mặc định
        }

        // ✅ KHẮC PHỤC LỖI ID: Luôn sử dụng chatId (được truyền là Order ID) để truy cập .doc()
        const chatDocRef = firestore.collection('chats').doc(chatId);

        // 2. TẠO HOẶC CẬP NHẬT TÀI LIỆU CHAT CHA VỚI TÊN
        try {
            console.log(`Bắt đầu tạo/cập nhật chats/${chatId}`);
            // Ghi tài liệu cha với tên để Flutter có thể đọc mà không cần quyền đọc 'users'
            await chatDocRef.set({
                // Các trường này giúp Rules xác định người tham gia
                userId: customerId,
                shipperId: shipperId,
                // Các trường này giúp Flutter tránh lỗi PERMISSION_DENIED trên users
                customerName: customerName,
                shipperName: shipperName,
                timestamp: FieldValue.serverTimestamp(),
            }, { merge: true });
            console.log(`✅ Thành công: Tài liệu chat cha chats/${chatId} đã được ghi (có tên và ID chính xác).`);
        } catch (dbError) {
            console.error('🔴 Lỗi Firestore khi tạo tài liệu CHAT CHA:', dbError);
            return res.status(500).send({ error: 'Lỗi Database khi khởi tạo Chat.' });
        }

        // 3. Ghi tin nhắn vào subcollection
        try {
            const chatRef = chatDocRef.collection('messages');
            await chatRef.add({
                senderId,
                message,
                timestamp: FieldValue.serverTimestamp(),
                // ✅ LƯU customerUID VÀ shipperUID VÀO TIN NHẮN (KHẮC PHỤC LATENCY RULES)
                customerUID,
                shipperUID,
            });
            console.log(`✅ Thành công: Tin nhắn đã được thêm vào chats/${chatId}/messages.`);
        } catch (dbError) {
             console.error('🔴 Lỗi Firestore khi thêm TIN NHẮN:', dbError);
             return res.status(500).send({ error: 'Lỗi Database khi thêm tin nhắn.' });
        }

        return res.status(200).send({ success: true, message: 'Đã gửi tin nhắn.' });
    } catch (error) {
        console.error('Lỗi chung khi gửi tin nhắn:', error);
        return res.status(500).send({ error: 'Server lỗi khi gửi tin nhắn.' });
    }
});


// Lấy danh sách tin nhắn (GIỮ NGUYÊN)
app.get('/api/v1/chat/:chatId', authenticateUser, async (req: AuthenticatedRequest, res: Response) => {
    try {
        const chatId = req.params.chatId;

        if (!chatId) {
            return res.status(400).send({ error: 'Thiếu chatId' });
        }

        const snapshot = await firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', 'asc')
            .get();

        const messages = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
        }));

        return res.status(200).send({ messages });
    } catch (error) {
        console.error('Lỗi lấy tin nhắn:', error);
        return res.status(500).send({ error: 'Server lỗi khi lấy tin nhắn.' });
    }
});

// ======================================================
// 🚀 CHẠY SERVER
// ======================================================
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
    console.log(`✅ Cloud Run Service listening on port ${PORT}`);
});