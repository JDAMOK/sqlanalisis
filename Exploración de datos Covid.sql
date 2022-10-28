/*
Covid 19 Data Exploration 

Skills utilizadas: Joins, subquerys, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/

--Importamos las tablas desde CSV, en SQL server--> click derecho en la ddbb/Tasks/Import data, seleccionamos Flat file source
--En destino seleccionar SQL Server Native client
use covid_db

--Cambiamos el tipo de dato en las columnas que sea necesario
alter table dbo.CovidDeaths alter column total_cases int

--Datos principales con los que vamos a trabajar
Select Location, date, total_cases, new_cases, total_deaths, population
From dbo.CovidDeaths
Where continent is not null 
order by 1,2

-- Total Cases vs Total Deaths
-- Comprobamos el % de letalidad del covid en nuestro pais

Select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as 'letalidad_rate'
From dbo.CovidDeaths
Where location like '%spain%'  
order by 'total_deaths'

--Cases vs Population. Porcentaje de personas infectadas por Covid

Select Location, date, total_cases, population, (total_cases/population)*100 as 'infection_rate'
From dbo.CovidDeaths
Where location like '%spain%'  
order by 'total_cases' desc

--Paises con la tasa de infección relativa mas alta comparandola con su población

Select Location, Population, MAX(total_cases) as HighestInfectionCount, Max((total_cases/population))*100 as PercentPopulationInfected
From dbo.CovidDeaths
where population != 0
Group by Location, Population
order by PercentPopulationInfected desc

--Localizaciones con mayor nº de muertos por Covid

Select Location, MAX(Total_deaths) as TotalDeathCount
From dbo.CovidDeaths
Group by Location
order by TotalDeathCount desc

--Continentes con mayor nº de muertos por Covid

Select continent, MAX(Total_deaths) as TotalDeathCount
From dbo.CovidDeaths
Group by continent
order by TotalDeathCount desc

--Total de casos a nivel mundial, total de muertos y porcentaje de mortalidad

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, 
		SUM(cast(new_deaths as int))/SUM(cast(New_Cases as float))*100 as DeathPercentage
From dbo.CovidDeaths

-- Total Vaccinations. Cantidad de dosis administradas

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
		SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) 
		as RollingPeopleVaccinated
From dbo.CovidDeaths dea
Join dbo.CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
order by 6 desc

-- Porcentaje de la población vacunada y nº de vacunas administradas. Aprovechando la query anterior, realizamos una subquery

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From dbo.CovidDeaths dea
Join dbo.CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
)
Select *, (RollingPeopleVaccinated/((CONVERT(float, Population)))*100) as vaccination_rate
From PopvsVac
where Population!=0
order by vaccination_rate desc

--Realizamos el mismo calculo que en la consulta anterior pero a través de la creación de una tabla temporal

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From dbo.CovidDeaths dea
Join dbo.CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date

Select *, (RollingPeopleVaccinated/((CONVERT(float, Population)))*100) as vaccination_rate
From #PercentPopulationVaccinated
where Population!=0
order by vaccination_rate desc

--Otra manera de lograr la query anterior sería a trvés de la creación de una vista

Create View [PercentPopulationVaccinated] as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From dbo.CovidDeaths dea
Join dbo.CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null

Select *, (RollingPeopleVaccinated/((CONVERT(float, Population)))*100) as vaccination_rate
From [PercentPopulationVaccinated]
where Population!=0
order by vaccination_rate desc
