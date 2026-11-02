import { connection } from "next/server";
import { createPublicSupabaseClient } from "@/lib/supabase/public";

export async function GET() {
    await connection();

    try {
        const supabase = createPublicSupabaseClient();

        const { data, error } = await supabase
            .from("practice_sets")
            .select("id, title, description, level, status")
            .order("title");

        if (error) {
            console.error("Không đọc được practice_sets:", error.message);

            return Response.json(
                { error: "Không thể tải danh sách bộ bài." },
                { status: 500 },
            );
        }

        return Response.json(
            { data },
            { headers: { "Cache-Control": "no-store" } },
        );
    } catch (error) {
        console.error("Lỗi cấu hình kết nối Supabase:", error);

        return Response.json(
            { error: "Chưa thể kết nối dịch vụ dữ liệu." },
            { status: 500 },
        );
    }
}