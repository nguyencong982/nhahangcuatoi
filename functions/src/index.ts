import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { defineString } from "firebase-functions/params";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import * as admin from 'firebase-admin';
import axios from "axios";

// Khởi tạo Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

// Định nghĩa Secret cho Mapbox Token
const MAPBOX_TOKEN_SECRET = defineString("MAPBOX_TOKEN_SECRET");

// ======================================================
// 🗺️ HÀM: LẤY LỘ TRÌNH MAPBOX (Giữ Nguyên)
// ======================================================

interface RouteRequestData {
  startLat: number;
  startLon: number;
  endLat: number;
  endLon: number;
}

export const getMapboxRoute = onCall<RouteRequestData>(async (request) => {
    const { data, auth } = request;

    if (!auth) {
        throw new HttpsError("unauthenticated", "Yêu cầu đăng nhập để tính lộ trình.");
    }

    const { startLat, startLon, endLat, endLon } = data;

    const startCoords = `${startLon},${startLat}`;
    const endCoords = `${endLon},${endLat}`;

    const mapboxApiUrl = `https://api.mapbox.com/directions/v5/mapbox/driving/${startCoords};${endCoords}`;

    try {
        const response = await axios.get(mapboxApiUrl, {
            params: {
                alternatives: "false",
                geometries: "polyline",
                overview: "full",
                access_token: MAPBOX_TOKEN_SECRET.value(),
            },
        });

        const route = response.data.routes[0];
        if (!route) {
            throw new HttpsError("not-found", "Không tìm thấy lộ trình từ Mapbox.");
        }

        let encodedPolyline = route.geometry;

        return {
            encodedPolyline: encodedPolyline,
            distanceMeters: route.distance,
        };
    } catch (error: any) {
        console.error("Lỗi gọi Mapbox API:", error?.message || error);
        throw new HttpsError("internal", "Lỗi server khi tính toán lộ trình Mapbox.");
    }
});


// ======================================================
// ⭐ LOGIC TÍNH TOÁN TỔNG HỢP ĐÁNH GIÁ (MÓN ĂN & QUÁN ĂN) ⭐
// ======================================================

// HÀM MỚI: Tái tính toán điểm trung bình và tổng số đánh giá cho RESTAURANT
async function recalculateRestaurantRating(restaurantId: string): Promise<void> {
    const restaurantRef = db.collection('restaurants').doc(restaurantId);

    // 1. Truy vấn TẤT CẢ MenuItem thuộc quán ăn này
    const menuItemsSnapshot = await restaurantRef
        .collection('menuItems')
        .get();

    let totalRestaurantReviews = 0;
    let weightedTotalRating = 0;

    menuItemsSnapshot.forEach(doc => {
        const data = doc.data();
        const avgRating = data.averageRating || 0;
        const totalReviews = data.totalReviews || 0;

        // Tổng hợp điểm: (Điểm TB Món Ăn * Tổng Review Món Ăn)
        weightedTotalRating += (avgRating * totalReviews);
        totalRestaurantReviews += totalReviews;
    });

    // 2. Tính điểm trung bình của quán
    const restaurantAverageRating = totalRestaurantReviews > 0
        ? weightedTotalRating / totalRestaurantReviews
        : 0;

    // 3. Cập nhật tài liệu Restaurant gốc
    try {
        await restaurantRef.update({
            averageRating: parseFloat(restaurantAverageRating.toFixed(2)),
            totalReviews: totalRestaurantReviews,
            restaurantAggregationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Updated Restaurant ${restaurantId}. Avg: ${restaurantAverageRating.toFixed(2)}, Total: ${totalRestaurantReviews}`);
    } catch (error) {
        console.error(`Error updating restaurant ${restaurantId}: ${error}`);
    }
}


/**
 * Tái tính toán điểm trung bình và tổng số đánh giá cho MenuItem.
 * @param itemId ID của món ăn (menuItem)
 * @param restaurantId ID của nhà hàng chứa món ăn
 */
async function recalculateAverageRating(itemId: string, restaurantId: string): Promise<void> {

    // 1. Xác định vị trí tài liệu cần cập nhật (MenuItem)
    const entityRef = db.collection('restaurants')
        .doc(restaurantId)
        .collection('menuItems')
        .doc(itemId);

    // 2. Truy vấn tất cả đánh giá liên quan
    const reviewsSnapshot = await db.collection('reviews')
        .where('menuItemId', '==', itemId)
        .get();

    // 3. Tính toán tổng hợp cho MenuItem
    const totalReviews = reviewsSnapshot.size;
    let totalRating = 0;

    reviewsSnapshot.forEach(doc => {
        const rating = doc.data().rating;
        if (typeof rating === 'number') {
            totalRating += rating;
        }
    });

    const averageRating = totalReviews > 0 ? totalRating / totalReviews : 0;

    // 4. Cập nhật tài liệu MenuItem
    try {
        await entityRef.update({
            averageRating: parseFloat(averageRating.toFixed(2)),
            totalReviews: totalReviews,
            reviewAggregationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Updated menuItem ${itemId} in restaurant ${restaurantId}. Avg: ${averageRating.toFixed(2)}, Total: ${totalReviews}`);

        // ⭐ BƯỚC QUAN TRỌNG: Gọi hàm tổng hợp điểm cho Quán ăn
        await recalculateRestaurantRating(restaurantId);

    } catch (error) {
        console.error(`Error updating menuItem ${itemId}: ${error}`);
    }
}

// -------------------------------------------------------------
// A. TRIGGER: Khi một đánh giá được TẠO (onCreate)
// -------------------------------------------------------------
export const onReviewCreate = onDocumentCreated('reviews/{reviewId}', async (event) => {
    const reviewData = event.data?.data();
    if (!reviewData || !reviewData.menuItemId || !reviewData.restaurantId) return;

    const itemId = reviewData.menuItemId as string;
    const restaurantId = reviewData.restaurantId as string;

    return recalculateAverageRating(itemId, restaurantId);
});

// -------------------------------------------------------------
// B. TRIGGER: Khi một đánh giá được CẬP NHẬT (onUpdate)
// -------------------------------------------------------------
export const onReviewUpdate = onDocumentUpdated('reviews/{reviewId}', async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || !after.menuItemId || !after.restaurantId) return;

    // Chỉ chạy lại nếu trường 'rating' thay đổi
    if (before.rating === after.rating) {
        return null;
    }

    const itemId = after.menuItemId as string;
    const restaurantId = after.restaurantId as string;

    return recalculateAverageRating(itemId, restaurantId);
});


// -------------------------------------------------------------
// C. TRIGGER: Khi một đánh giá bị XÓA (onDelete)
// -------------------------------------------------------------
export const onReviewDelete = onDocumentDeleted('reviews/{reviewId}', async (event) => {
    const reviewData = event.data?.data();
    if (!reviewData || !reviewData.menuItemId || !reviewData.restaurantId) return;

    const itemId = reviewData.menuItemId as string;
    const restaurantId = reviewData.restaurantId as string;

    return recalculateAverageRating(itemId, restaurantId);
});