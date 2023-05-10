--SELECT *
--FROM PortfolioProject..CovidVaccinations
--ORDER BY 3,4

SELECT *
FROM PortfolioProject..CovidDeaths
WHERE continent IS NULL
ORDER BY 3,4


-- Select Data that we are going to be using

SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL -- deleting all data without specific country (like Asia or World)
ORDER BY 1,2

-- Changing dataype of NEEDED numeric data to float (only 1 column can be altered in one statement)
-- Another way to change datatype is to use 'cast(total_deaths as float)' in SELECT statement
-- We can not use 'integer' type because it has limit of 2 147 483 647 while some numbers are higher

ALTER TABLE PortfolioProject..CovidDeaths
ALTER COLUMN total_deaths float

ALTER TABLE PortfolioProject..CovidDeaths
ALTER COLUMN total_cases float

-- Looking at Total Cases vs Total Deaths 
-- It's like what are the chances to die if you got the covid (in Argentina)

SELECT Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE Location = 'Argentina'
ORDER BY 1,2

-- Looking at Total Cases vs Population

SELECT Location, date, population, total_cases, (total_cases/population)*100 AS InfectionRate
FROM PortfolioProject..CovidDeaths
WHERE Location = 'Argentina'
ORDER BY 1,2

-- Looking at the countries with the highest ifection rate compared to population

SELECT Location, population, MAX(total_cases) AS HighestInfectionCount, (MAX(total_cases)/population)*100 AS InfectionRate
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location, population
ORDER BY 4 DESC


-- Looking at the countries with the highest death count

SELECT Location, MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location, population
ORDER BY TotalDeathCount DESC


-- Breaking down the DeathCount by continent
-- When we SELECT continent and NOT NULL, it somehow returns different numbers, where NA=USA, which is NOT correct.

SELECT location, MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS NULL
GROUP BY location
ORDER BY TotalDeathCount DESC


-- GLOBAL NUMBERS

SELECT date, SUM(new_cases) AS SumNewCases, SUM(new_deaths) AS SumNewDeaths
, SUM(new_deaths)/NULLIF(SUM(new_cases),0)*100 AS DeathPercentage --!!! NULLIF eliminates 'Division by zero' error
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL --!!! REALLY IMPORTANT, otherwise the numbers are quadrupled because of different partition - WORLD, INCOME, CONTINENTS...
GROUP BY date
ORDER BY 1


-- Looking at Total Population vs Vaccinations

ALTER TABLE PortfolioProject..CovidVaccinations
ALTER COLUMN new_vaccinations float
-- another way - CONVERT(float,vac.new_vaccinations) - in SELECT statement
-- another way - CAST(vac.new_vaccinations as float) - in SELECT statement
-- CAST is used more often and is similar to other programming languages
-- only ALTER COLUMN permanently changes datatype in a database,
-- others only change the interpretation of data in a query

-- Variant 1 (Join + Partition)

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date) AS TotalVaccinationsToDate
, (SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date))/population*100 AS PercentageVaccinated
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3


-- Variant 2 (CTE + Join + Partition)

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, TotalVaccinationsToDate)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date) AS TotalVaccinationsToDate
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3
)
SELECT *, TotalVaccinationsToDate/population*100 AS PercentageVaccinated
FROM PopvsVac


-- Variant 3 (Temp Table + Join + Partition)

DROP TABLE IF EXISTS #PercentagePopulationVaccinated
CREATE TABLE #PercentagePopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
TotalVaccinationsToDate numeric
)

INSERT INTO #PercentagePopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date) AS TotalVaccinationsToDate
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

SELECT *, TotalVaccinationsToDate/population*100 AS PercentageVaccinated
FROM #PercentagePopulationVaccinated
ORDER BY 2,3


-- Creating view to store data for later viz

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date) AS TotalVaccinationsToDate
, (SUM(vac.new_vaccinations) OVER (Partition by dea.location ORDER BY dea.location, dea.date))/population*100 AS PercentageVaccinated
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL