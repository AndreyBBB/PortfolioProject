-- Cleaning data project
-- Thanks to Alex The Analyst
-- Database https://github.com/AlexTheAnalyst/PortfolioProjects/blob/main/Nashville%20Housing%20Data%20for%20Data%20Cleaning.xlsx

SELECT *
FROM PortfolioProject..NashvilleHousing


-- Standardize date format

SELECT SaleDate
FROM PortfolioProject..NashvilleHousing

ALTER TABLE PortfolioProject..NashvilleHousing
ALTER COLUMN SaleDate date
-- We can add another column and CONVERT + copy date to it if we have to save the original column
-- Or we can update the table:
-- Update NashvilleHousing
-- SET SaleDate = CONVERT(Date, SaleDate)
-- The difference is that ALTER changes the table structure, while UPDATE only changes data
-- I can't see the difference in my case, so I use ALTER

-- Populate property address data

-- 1 - Checking for NULL values
SELECT PropertyAddress
FROM PortfolioProject..NashvilleHousing
WHERE PropertyAddress IS NULL

-- 2 - Checking if there is another data in these rows
SELECT *
FROM PortfolioProject..NashvilleHousing
WHERE PropertyAddress IS NULL

-- 3 - Checking if there is an Address in a table with the same ParcellID
-- Joining a table to its copy (Self Join)
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
FROM PortfolioProject..NashvilleHousing AS a
JOIN PortfolioProject..NashvilleHousing AS b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ] -- !!! THE MOST IMPORTANT PART !!!
WHERE a.PropertyAddress IS NULL

-- Populating NULL values, copying Address from the same ParcelID
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject..NashvilleHousing AS a
JOIN PortfolioProject..NashvilleHousing AS b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL

-- NULL Address - problem fixed


-- Breaking out Address into individual columns - Address, City, State
-- 1 - PropertyAddress (initially Address+City)
-- Using SUBSTRING

SELECT PropertyAddress
FROM PortfolioProject..NashvilleHousing

SELECT
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address
, SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City
-- +1 & -1 are for excluding ','
FROM PortfolioProject..NashvilleHousing


-- Adding 2 new columns - PropertySplitAddress and PropertySplitCity
-- Execute 1 by 1

ALTER TABLE NashvilleHousing
ADD PropertySplitAddress nvarchar(255)

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)

ALTER TABLE NashvilleHousing
ADD PropertySplitCity nvarchar(255)

UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress))

SELECT *
FROM PortfolioProject..NashvilleHousing

-- 2 - OwnerAddress (initially Address+City+State)
-- Using PARSENAME (It's actually looks like a cheat!)
-- Returns parts of the object's name, divided by '.' starting from the last one (Using REPLACE to change ',' to '.')
-- Be careful - can return up to 4 parts, each up to 128 characters, datatype = sysname (equivalent to nvarchar(128)
-- Any part longer than 128 characters returns NULL. NULL (or nonexisting part) returns NULL.

SELECT *
FROM PortfolioProject..NashvilleHousing
WHERE OwnerAddress IS NULL
-- There are 30462 rows without Owner's data (just to consider)
-- And there is no chance to populate these values

SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) AS OwnerSplitState
, PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) AS OwnerSplitCity
, PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) AS OwnerSplitAddress
FROM PortfolioProject..NashvilleHousing

-- Adding 3 new columns - OwnerSplitState, OwnerSplitCity, OwnerSplitAddress
-- Execute 1 by 1, not all at once

ALTER TABLE NashvilleHousing
ADD OwnerSplitState nvarchar(255)

UPDATE NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)

ALTER TABLE NashvilleHousing
ADD OwnerSplitCity nvarchar(255)

UPDATE NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)

ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress nvarchar(255)

UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)

SELECT *
FROM PortfolioProject..NashvilleHousing


-- Changing Y and N to Yes and No in SoldAsVacant (making data consistent)

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant) --checking for inconsistency
FROM PortfolioProject..NashvilleHousing
GROUP BY SoldAsVacant --'Yes' and 'No' are much more consistant, so we'll keep it
ORDER BY 2


SELECT SoldAsVacant
, CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END
FROM PortfolioProject..NashvilleHousing

-- After checking that it works, changing the column

UPDATE NashvilleHousing
SET SoldAsVacant = 
  CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END

SELECT DISTINCT(SoldAsVacant) --checking for consistency - everithing is OK now
FROM PortfolioProject..NashvilleHousing


-- Removing duplicates using CTE
-- WARNING! - usually we have to save the original data, so check it twice!

WITH RowNumCTE AS(
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) AS row_num
FROM PortfolioProject..NashvilleHousing
)
SELECT *
FROM RowNumCTE
WHERE row_num > 1
ORDER BY PropertyAddress

-- It shows, we have 104 duplicated rows (at least with duplicated fields we asked about)

-- Now we can actually DELETE these duplicates

WITH RowNumCTE AS(
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) AS row_num
FROM PortfolioProject..NashvilleHousing
)
DELETE
FROM RowNumCTE
WHERE row_num > 1

-- It shows 104 rows were affected, now we can go back and check once more for duplicates - there are none


-- Deleting unnecessary columns
-- WARNING! Once again - check it twice, before deleting!
-- Usually it's acceptable for creating views or working with copies of data, not the raw data!

SELECT *
FROM PortfolioProject..NashvilleHousing

--ALTER TABLE PortfolioProject..NashvilleHousing
--DROP COLUMN PropertyAddress, OwnerAddress

--I will not do it right now, but it's safe to delete addresses, which we splitted in new columns
--Maybe there is more to delete depending on the goals of the analysis


-- RESUME of data cleaning
-- 1. SaleData format changed
-- 2. NULL values in PropertyAddress column - checked and populated
-- 3. PropertyAddress and OwnerAddress - splitted into new columns (Address, City, State)
-- 4. Inconsistency in SoldAsVacant column (Y, N, Yes, No) - fixed
-- 5. Duplicate rows - checked and deleted
-- 6. Unnecessary columns - prepared to delete
