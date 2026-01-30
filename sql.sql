CREATE TABLE IF NOT EXISTS `rs_dailygift` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `last_claim_day` VARCHAR(16) NULL,
  `streak` INT NOT NULL DEFAULT 0,
  `total_claims` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_identifier` (`identifier`)
);
