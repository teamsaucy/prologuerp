-- prologue_garage install
-- The garage stores vehicles using the existing owned_vehicles table.
-- It uses the 'stored' column (1 = in garage, 0 = out) and 'parking' column 
-- to track which garage the vehicle is stored at.
--
-- If your owned_vehicles table doesn't have a 'parking' column, run this:

ALTER TABLE `owned_vehicles` 
ADD COLUMN IF NOT EXISTS `parking` VARCHAR(60) DEFAULT NULL;

ALTER TABLE `owned_vehicles` 
ADD COLUMN IF NOT EXISTS `nickname` VARCHAR(60) DEFAULT NULL;
