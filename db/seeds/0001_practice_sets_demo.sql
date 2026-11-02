BEGIN;

INSERT INTO public.practice_sets (
    id, title, description, level, status
)
VALUES
    (
        '11111111-1111-4111-8111-111111111111',
        '[DEMO] N3 — Ngữ pháp 01',
        'Dữ liệu kiểm tra kết nối; chưa có câu hỏi.',
        'N3',
        'published'
    ),
    (
        '22222222-2222-4222-8222-222222222222',
        '[DEMO] N3 — Bản nháp',
        'Dữ liệu kiểm tra: người dùng web không được thấy bản này.',
        'N3',
        'draft'
    )
ON CONFLICT (id) DO NOTHING;

COMMIT;