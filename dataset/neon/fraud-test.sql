\set ON_ERROR_STOP on

-- Casos controlados para validar RULE_CARD_TESTING sem modificar os 2.000 registros base.
-- O cartão escolhido existe no dataset e não faz parte dos casos controlados de RULE_VELOCITY.
-- O caso positivo também satisfaz RULE_VELOCITY; essa sobreposição é esperada pela definição das regras.

DELETE FROM payments.transactions
WHERE transaction_id IN (
    '8ed913b2-3758-51d8-8340-4426d3170f3e','94963bb7-77fa-5891-ae58-a9cc77b1cb87','06d26530-5f57-5d6e-bfe8-c8324161e059',
    '86cb95f4-f658-5536-ae10-307f055c4ee3','46bf3572-20d9-51cf-942f-c7f4c2b747a2','d550ddeb-a834-5ab4-b867-5d80830507ea',
    '93855a92-969d-5ed0-851a-8e26a740e1be','c3f380df-b23c-5181-a110-334ada24db0d','d0c028a0-32d2-53ad-b7c6-2a2b093a2700'
);

INSERT INTO payments.transactions
(transaction_id, account_id, card_id, merchant_id, channel, amount, currency, mcc, transaction_state, status, decline_reason, created_at, authorized_at, settled_at)
VALUES
-- Positivo: 3 valores <= 20 em 8 segundos.
('8ed913b2-3758-51d8-8340-4426d3170f3e','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',5.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:00:00+00:00','2026-03-01T12:00:01+00:00',NULL),
('94963bb7-77fa-5891-ae58-a9cc77b1cb87','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',9.90,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:00:04+00:00','2026-03-01T12:00:05+00:00',NULL),
('06d26530-5f57-5d6e-bfe8-c8324161e059','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',15.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:00:08+00:00','2026-03-01T12:00:09+00:00',NULL),
-- Negativo por tempo: 12 segundos.
('86cb95f4-f658-5536-ae10-307f055c4ee3','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',5.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:10:00+00:00','2026-03-01T12:10:01+00:00',NULL),
('46bf3572-20d9-51cf-942f-c7f4c2b747a2','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',9.90,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:10:05+00:00','2026-03-01T12:10:06+00:00',NULL),
('d550ddeb-a834-5ab4-b867-5d80830507ea','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',15.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:10:12+00:00','2026-03-01T12:10:13+00:00',NULL),
-- Negativo por valor: janela de 8 segundos, mas uma transação > 20.
('93855a92-969d-5ed0-851a-8e26a740e1be','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',5.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:20:00+00:00','2026-03-01T12:20:01+00:00',NULL),
('c3f380df-b23c-5181-a110-334ada24db0d','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',25.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:20:04+00:00','2026-03-01T12:20:05+00:00',NULL),
('d0c028a0-32d2-53ad-b7c6-2a2b093a2700','c942c9c7-5a50-54c6-82bf-ec0b6adc2f88','27772a4e-27a2-5502-852d-1fb1b608a060','95212d6d-1a83-5e35-9df8-6c572b7592d0','CREDIT',15.00,'BRL','5411','PB','APPROVED',NULL,'2026-03-01T12:20:08+00:00','2026-03-01T12:20:09+00:00',NULL);
