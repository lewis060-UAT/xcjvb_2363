use final_data_4OpioidPaper
GO

--------------------------------Function for the Basic Two Step Float--------------------------------
CREATE FUNCTION dbo.basic_2SFCA 
( @time int
 ,@facType1 varchar(50)
 ,@facType2 varchar(50)
 ,@curveOrig varchar(50)
)
RETURNS TABLE
AS
RETURN
	(
	select A.GEOID_Data
		  ,isnull(sum(prov10K),0) as locs_per_10K
		  ,'2SFCA' as [Model Type]
		  ,@time as [TravelTime Catchment]
		  ,@curveOrig as [Curve Origin]
	from
	[final_data_4OpioidPaper].[dbo].[popTable] a
	left join
	(
	select a.*,b.prov10K
	from [final_data_4OpioidPaper].[dbo].[OD] a left join 
	(
	select
	USER_KEYid, (1/(sum(b.total18to64)*1.00))*10000 as prov10K
	from 
	[final_data_4OpioidPaper].[dbo].[OD] a left join [final_data_4OpioidPaper].[dbo].[popTable] b on a.GEOID_Data=b.GEOID_Data
	where a.Total_TravelTime<=@time-->parameter to cap time for 2SFCA
	and USER_KEYid in (select KEYid from [final_data_4OpioidPaper].[dbo].[FAC] where fac_type in (@facType1,@facType2))-->parameter in "where fac_type list to determine facility type
	group by a.USER_KEYid
	)
	b on a.USER_KEYid=b.USER_KEYid
	)Q
	on a.GEOID_Data=Q.GEOID_Data 
	group by a.GEOID_Data
	);
GO


--------------------------------Function for the Enhanced Two Step Float With Downward Log Logistic Decay--------------------------------
CREATE FUNCTION dbo.enhanced_2SFCA 
( @time int
 ,@b0 float
 ,@b1 float
 ,@facType1 varchar(50)
 ,@facType2 varchar(50)
 ,@curveOrig varchar(50)
)
RETURNS TABLE
AS
RETURN
	(
	select A.GEOID_Data
		  ,isnull(sum(prov10K*(1/(1+power((q.[Total_TravelTime]/@b0),@b1)))),0) as locs_per_10K
		  ,'E2SFCA' as [Model Type]
		  ,@time as [TravelTime Catchment]
		  ,@curveOrig as [Curve Origin]
	from
	[final_data_4OpioidPaper].[dbo].[popTable] a
	left join
	(
	select a.*,b.prov10K
	from [final_data_4OpioidPaper].[dbo].[OD] a left join 
	(
	select
	USER_KEYid, (1/(sum(b.total18to64*(1/(1+power((a.[Total_TravelTime]/@b0),@b1))))*1.00))*10000 as prov10K --> parameter for beta weights of decay function
	from 
	[final_data_4OpioidPaper].[dbo].[OD] a left join [final_data_4OpioidPaper].[dbo].[popTable] b on a.GEOID_Data=b.GEOID_Data
	and USER_KEYid in (select KEYid from [final_data_4OpioidPaper].[dbo].[FAC] where fac_type in (@facType1,@facType2))-->parameter in "where fac_type list to determine facility type
	where a.Total_TravelTime<=@time and b.total18to64>0-->parameter to cap time for E2SFCA
	group by a.USER_KEYid
	)
	b on a.USER_KEYid=b.USER_KEYid
	where a.Total_TravelTime<=@time-->parameter to cap time for E2SFCA
	)Q
	on a.GEOID_Data=Q.GEOID_Data 
	group by a.GEOID_Data
	);
GO  

--------------------------------Function for the Modified Two Step Float With Downward Log Logistic Decay--------------------------------
CREATE FUNCTION dbo.modified_2SFCA 
( @time int
 ,@b0 float
 ,@b1 float
 ,@facType1 varchar(50)
 ,@facType2 varchar(50)
 ,@curveOrig varchar(50)
)
RETURNS TABLE
AS
RETURN
	(
		select distinct
		 A.GEOID_Data
		,isnull(B.M2SFCA_Min,0) as locs_per_10K
		,'M2SFCA' as [Model Type]
		,@time as [TravelTime Catchment]
		,@curveOrig as [Curve Origin]
		from
		(select distinct 
		GEOID_Data 
		from [final_data_4OpioidPaper].[dbo].[popTable]
		)A
		left join
		(select distinct
		 A.GEOID_Data
		,sum(B.initRatio*(1/(1+power(([Total_TravelTime]/@b0),@b1)))) as M2SFCA_Min --> parameter for beta weights of decay function
		from 
		[final_data_4OpioidPaper].[dbo].[OD] A
		left join
		(
		select distinct
		 A.GEOID_Data
		,A.USER_KEYid 
		,(A.num_Min/B.initRatio_Min)*10000 as initRatio
		from
		(select distinct 
		GEOID_Data, USER_KEYid
		,(1*(1/(1+power(([Total_TravelTime]/@b0),@b1)))) as num_Min ----> parameter for beta weights of decay function
		from [final_data_4OpioidPaper].[dbo].[OD]
		where USER_KEYid in (select KEYid from [final_data_4OpioidPaper].[dbo].[FAC] where fac_type in (@facType1,@facType2)) -->parameter in "where fac_type list to determine facility
		and Total_TravelTime<=@time)A  -->parameter to cap time for M2SFCA
		left join
		(select
		 USER_KEYid
		,sum(b.total18to64*(1/(1+power((a.[Total_TravelTime]/@b0),@b1)))) as initRatio_Min --> parameter for beta weights of decay function
		from [final_data_4OpioidPaper].[dbo].[OD] a left join [final_data_4OpioidPaper].[dbo].[popTable] b on a.GEOID_Data=b.GEOID_Data
		where a.USER_KEYid in (select KEYid from [final_data_4OpioidPaper].[dbo].[FAC] where fac_type in (@facType1,@facType2)) -->parameter in "where fac_type list to determine facility 
		and a.Total_TravelTime<=@time and b.total18to64>0-->parameter to cap time for M2SFCA
		group by USER_KEYid)B
		on A.USER_KEYid=b.USER_KEYid
		where a.USER_KEYid in (select KEYid from [final_data_4OpioidPaper].[dbo].[FAC] where fac_type in (@facType1,@facType2))-->parameter in "where fac_type list to determine facility
			)B
			on A.GEOID_Data=B.GEOID_Data and A.USER_KEYid=B.USER_KEYid 
		where a.Total_TravelTime<=@time -->parameter to cap time for M2SFCA
		group by A.GEOID_Data)B
		on A.GEOID_Data=B.GEOID_Data);
GO


--------------------------------------------------------------Notes About Functions__________________________________________
----Basic 2SFCA
--base formula for 2SFCA Function
--				  basic_2SFCA ( 
--							   time catchment (int)
--							  ,facilty type 1 [OTP or Buprenorphine] (str)
--							  ,facilty type 2 [OTP or Buprenorphine] (str)
--							  ,Origin of Data for Decay (str)
--							 )
--SELECT * FROM basic_2SFCA(30, 'OTP', '','No Decay') order by GEOID_Data;


----Enhanced 2SFCA
--base formula for E2SFCA Function
--			  enhanced_2SFCA ( 
--							   time catchment (int)
--							  ,b0 for DLL function (float)
--							  ,b1 for DLL function (float)
--							  ,facilty type 1 [OTP or Buprenorphine] (str)
--							  ,facilty type 2 [OTP or Buprenorphine] (str)
--							  ,Origin of Data for Decay (str)
--							 )
--SELECT * FROM enhanced_2SFCA(9.062637, 2.261168,'OTP', '','Decay from SOSOSO et al.') order by GEOID_Data;


----Modified 2SFCA
--base formula for M2SFCA Function
--			  modified_2SFCA ( 
--							   time catchment (int)
--							  ,b0 for DLL function (float)
--							  ,b1 for DLL function (float)
--							  ,facilty type 1 [OTP or Buprenorphine] (str)
--							  ,facilty type 2 [OTP or Buprenorphine] (str)
--							  ,Origin of Data for Decay (str)
--							 )
--SELECT * FROM modified_2SFCA(9.062637, 2.261168,'OTP', '','Decay from SOSOSO et al.') order by GEOID_Data;
