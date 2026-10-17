-- Preparação das tabelas para evidenciar before/after completos no CDC.
-- Credenciais do cdc_user não são versionadas neste arquivo.

ALTER TABLE payments.customers REPLICA IDENTITY FULL;
ALTER TABLE payments.accounts REPLICA IDENTITY FULL;
ALTER TABLE payments.cards REPLICA IDENTITY FULL;
ALTER TABLE payments.merchants REPLICA IDENTITY FULL;
ALTER TABLE payments.transactions REPLICA IDENTITY FULL;
