BEGIN;

-- Cho phép hai vai trò sử dụng schema.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Chỉ cấp quyền đọc bảng thông tin bộ bài.
GRANT SELECT ON TABLE public.practice_sets
    TO anon, authenticated;

-- RLS giới hạn chỉ đọc các bộ bài đã xuất bản.
CREATE POLICY practice_sets_read_published
    ON public.practice_sets
    FOR SELECT
    TO anon, authenticated
    USING (status = 'published');

COMMIT;