BEGIN;

-- 1. Hồ sơ: tài khoản và mật khẩu do Supabase Auth quản lý.
CREATE TABLE public.profiles (
                                 id UUID PRIMARY KEY
                                     REFERENCES auth.users(id) ON DELETE CASCADE,

                                 display_name TEXT NOT NULL
                                     CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 100),

                                 target_level TEXT NOT NULL DEFAULT 'N3'
                                     CHECK (target_level IN ('N5', 'N4', 'N3', 'N2', 'N1')),

                                 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Bộ bài.
CREATE TABLE public.practice_sets (
                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

                                      title TEXT NOT NULL
                                          CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),

                                      description TEXT NOT NULL DEFAULT '',

                                      level TEXT NOT NULL
                                          CHECK (level IN ('N5', 'N4', 'N3', 'N2', 'N1')),

                                      status TEXT NOT NULL DEFAULT 'draft'
                                          CHECK (status IN ('draft', 'published', 'archived')),

                                      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Câu hỏi. Bản đầu chỉ hỗ trợ trắc nghiệm một đáp án.
CREATE TABLE public.questions (
                                  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

                                  prompt TEXT NOT NULL
                                      CHECK (char_length(btrim(prompt)) > 0),

                                  level TEXT NOT NULL
                                      CHECK (level IN ('N5', 'N4', 'N3', 'N2', 'N1')),

                                  skill TEXT NOT NULL DEFAULT 'grammar'
                                      CHECK (skill IN ('grammar', 'vocabulary', 'kanji', 'reading')),

                                  status TEXT NOT NULL DEFAULT 'draft'
                                      CHECK (status IN ('draft', 'published', 'archived')),

                                  source_note TEXT NOT NULL DEFAULT '',

                                  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Phương án trả lời.
CREATE TABLE public.question_options (
                                         id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

                                         question_id UUID NOT NULL
                                             REFERENCES public.questions(id) ON DELETE CASCADE,

                                         content TEXT NOT NULL
                                             CHECK (char_length(btrim(content)) > 0),

                                         position SMALLINT NOT NULL
                                             CHECK (position BETWEEN 1 AND 4),

                                         CONSTRAINT uq_option_position
                                             UNIQUE (question_id, position),

    -- Dùng làm đích cho FK ghép:
    -- phương án phải thuộc đúng câu hỏi.
                                         CONSTRAINT uq_option_question_id
                                             UNIQUE (question_id, id)
);

-- 5. Đáp án chuẩn.
CREATE TABLE public.answer_keys (
                                    question_id UUID PRIMARY KEY
                                        REFERENCES public.questions(id) ON DELETE CASCADE,

                                    correct_option_id UUID NOT NULL,

                                    explanation TEXT NOT NULL
                                        CHECK (char_length(btrim(explanation)) > 0),

                                    CONSTRAINT fk_correct_option
                                        FOREIGN KEY (question_id, correct_option_id)
                                            REFERENCES public.question_options(question_id, id)
                                            ON DELETE NO ACTION
);

-- 6. Quan hệ nhiều-nhiều giữa bộ bài và câu hỏi.
CREATE TABLE public.practice_set_questions (
                                               practice_set_id UUID NOT NULL
                                                   REFERENCES public.practice_sets(id) ON DELETE RESTRICT,

                                               question_id UUID NOT NULL
                                                   REFERENCES public.questions(id) ON DELETE RESTRICT,

                                               position INTEGER NOT NULL
                                                   CHECK (position > 0),

                                               PRIMARY KEY (practice_set_id, question_id),

                                               CONSTRAINT uq_set_question_position
                                                   UNIQUE (practice_set_id, position)
);

-- 7. Lần làm bài.
CREATE TABLE public.attempts (
                                 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

                                 user_id UUID NOT NULL
                                     REFERENCES public.profiles(id) ON DELETE CASCADE,

                                 practice_set_id UUID NOT NULL
                                     REFERENCES public.practice_sets(id) ON DELETE RESTRICT,

                                 status TEXT NOT NULL DEFAULT 'in_progress'
                                     CHECK (status IN ('in_progress', 'submitted')),

                                 started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                                 submitted_at TIMESTAMPTZ,

    -- Chưa nộp thì chưa có điểm.
                                 correct_count INTEGER,
                                 total_count INTEGER,

                                 CONSTRAINT uq_attempt_set
                                     UNIQUE (id, practice_set_id),

                                 CONSTRAINT ck_attempt_submission
                                     CHECK (
                                         (
                                             status = 'in_progress'
                                                 AND submitted_at IS NULL
                                                 AND correct_count IS NULL
                                                 AND total_count IS NULL
                                             )
                                             OR
                                         (
                                             status = 'submitted'
                                                 AND submitted_at IS NOT NULL
                                                 AND correct_count IS NOT NULL
                                                 AND total_count IS NOT NULL
                                                 AND total_count > 0
                                                 AND correct_count BETWEEN 0 AND total_count
                                             )
                                         ),

                                 CONSTRAINT ck_attempt_time
                                     CHECK (
                                         submitted_at IS NULL
                                             OR submitted_at >= started_at
                                         )
);

-- 8. Câu trả lời của người học.
CREATE TABLE public.attempt_answers (
                                        attempt_id UUID NOT NULL,
                                        practice_set_id UUID NOT NULL,
                                        question_id UUID NOT NULL,

    -- NULL: chưa chọn hoặc đã bỏ lựa chọn.
                                        selected_option_id UUID,

    -- NULL: chưa chấm.
                                        is_correct BOOLEAN,

                                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

                                        PRIMARY KEY (attempt_id, question_id),

    -- Đảm bảo practice_set_id đúng với lần làm bài.
                                        CONSTRAINT fk_answer_attempt
                                            FOREIGN KEY (attempt_id, practice_set_id)
                                                REFERENCES public.attempts(id, practice_set_id)
                                                ON DELETE CASCADE,

    -- Đảm bảo câu hỏi thuộc bộ bài đang làm.
                                        CONSTRAINT fk_answer_set_question
                                            FOREIGN KEY (practice_set_id, question_id)
                                                REFERENCES public.practice_set_questions(
                                                                                         practice_set_id, question_id
                                                    )
                                                ON DELETE RESTRICT,

    -- Đảm bảo phương án được chọn thuộc đúng câu hỏi.
                                        CONSTRAINT fk_answer_selected_option
                                            FOREIGN KEY (question_id, selected_option_id)
                                                REFERENCES public.question_options(question_id, id)
                                                ON DELETE RESTRICT,

                                        CONSTRAINT ck_correct_answer_has_selection
                                            CHECK (
                                                is_correct IS DISTINCT FROM TRUE
                                                OR selected_option_id IS NOT NULL
)
    );

-- Index cho lịch sử làm bài và các FK chưa có index phù hợp.
CREATE INDEX idx_attempts_user_started
    ON public.attempts(user_id, started_at DESC);

CREATE INDEX idx_attempts_practice_set
    ON public.attempts(practice_set_id);

CREATE INDEX idx_set_questions_question
    ON public.practice_set_questions(question_id);

CREATE INDEX idx_attempt_answers_set_question
    ON public.attempt_answers(practice_set_id, question_id);

CREATE INDEX idx_attempt_answers_selected_option
    ON public.attempt_answers(question_id, selected_option_id);

CREATE INDEX idx_answer_keys_selected_option
    ON public.answer_keys(question_id, correct_option_id);

-- Bật bảo vệ theo dòng.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answer_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_set_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempt_answers ENABLE ROW LEVEL SECURITY;

-- Chưa mở quyền truy cập qua các vai trò người dùng web.
-- Sẽ bổ sung quyền và policy trong migration tiếp theo.
REVOKE ALL ON TABLE
    public.profiles,
    public.practice_sets,
    public.questions,
    public.question_options,
    public.answer_keys,
    public.practice_set_questions,
    public.attempts,
    public.attempt_answers
    FROM PUBLIC, anon, authenticated;

COMMIT;