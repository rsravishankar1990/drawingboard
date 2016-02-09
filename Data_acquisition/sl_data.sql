
select 
		A.sl_uuid, 		
		A.churn_flag,
		A.churn_flag_2,
		A.customer_life_bucket,
		'%WINDOW_START_DATE%'::date - A.sl_activated_date as customer_life,	
		case
		when A.equipment_activated_date is null then '%WINDOW_START_DATE%'::date - A.sl_activated_date
		when A.equipment_activated_date is not null and A.equipment_activated_date <= '%WINDOW_START_DATE%' then '%WINDOW_START_DATE%'::date - A.equipment_activated_date
		when A.equipment_activated_date is not null and A.equipment_activated_date > '%WINDOW_START_DATE%' then '%WINDOW_START_DATE%'::date - A.sl_activated_date
		end as device_life, 	
		A.sl_activated_date, 	
		A.sl_deactivated_date,
		A.plan_type,
		A.device_type,
		case
			when B.swap is null then 0
			else B.swap
			end as swap,
		case
			when B.replacement is null then 0
			else B.replacement
			end as replacement
		
		--Table B: Device switch and Device upgrade information
		--Device switch: Has customer used multiple devices in the past? - can this come from customer_history?
		--Device switch: Has customer just swapped devices in the past? - Can this come from Salesforce_transaction_items
		--Device switch: Has customer upgraded phones? - can this be obtained from device type info?
		--Device android version upgraded? - need to find out from chat
		

from




(
select 
				sl_uuid,
				email, 
				last_invoice_date,
				sl_activated_date,
				sl_deactivated_date,
				equipment_activated_date,
				case 
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 35 then 'Trialer'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 90 then '3 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 180 then '6 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 270 then '9 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 360 then '12 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 450 then '15 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 540 then '18 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 630 then '21 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 720 then '24 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 810 then '27 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 900 then '30 Months'
when '%WINDOW_START_DATE%'::date - sl_activated_date <= 1080 then '33 Months'
else '> 33 months'
end as customer_life_bucket,
				
				case
					when plan_base like '%Talk + Text%' then 'Talk & Text'
					when plan_base like '%Cell + 3G%' or plan_base like '%Cell + 4G%' then 'G3 or G4'
					when plan_base like '%Refund%' then 'Refund base'
					when plan_base like '%Wi-Fi Only%' then 'Wifi-Only'
					else 'Other plan - Discard'
					end as plan_type,
				case
					when sl_deactivated_date is null then 0
				when sl_deactivated_date between '%WINDOW_START_DATE%'::DATE + 1 AND '%WINDOW_END_DATE%' THEN 1
					else 0
				end as churn_flag,	
				case
					when sl_deactivated_date is null then 0
				when sl_deactivated_date between '%WINDOW_START_DATE%'::DATE + 1 AND '%WINDOW_END_DATE%'::date + 30 THEN 1
					else 0
				end as churn_flag_2,
				     case
						when most_recent_equipment like '%Moto E 2nd%' then 'Moto E2'
						when most_recent_equipment like '%Moto E Phone%' then 'Moto E'
						when most_recent_equipment like '%Moto E Proto%' then 'Moto E'
						when most_recent_equipment like '%Moto G 16%' or most_recent_equipment like '%Moto G 8%' then 'Moto G'
						when most_recent_equipment like '%Moto G 3rd%' then 'Moto G3'
						when most_recent_equipment like '%Moto X 2nd%' then 'Moto X2'
						when most_recent_equipment like '%Moto X Phone%' then 'Moto X'
						when most_recent_equipment like '%Moto X%' then 'Moto X'
						when most_recent_equipment like '%Moto DEFY%' then 'Defy'
						else 'Other'
					end as device_type
		
		from customer_view 
		where sl_activated_date <= '%WINDOW_START_DATE%'::date 
		and (sl_deactivated_date is null or sl_deactivated_date > '%WINDOW_START_DATE%')
		and email not like '%bandwidth.com%'
) AS A

	



left join

(
select sl_uuid, sum(swap) as swap, sum(replacement) as replacement
from(
	select 
			a.sl_uuid,
			b.type as device_trans_type,
			b.date as device_date,
			b.name as device_name,
			b.model as trans_model,
			b.category as trans_category,
			case
				when b.type = 'Swap' then 1
				else 0
			end as swap,
			case
				when b.type = 'Replacement' then 1
				else 0
			end as replacement
	from
		customer_history as a
	left join
		(
			  select A.sl_uuid, A.type, A.time_stamp::date as date, B.name, A.product_sku, B.model, B.category
			  from salesforce_transaction_items as A
			  left join
			  sku_dictionary as B
			  on A.product_sku = B.sku
			  where B.model = 'device' and A.time_stamp between '%WINDOW_START_DATE%'::date - 180 and '%WINDOW_START_DATE%'::date and A.type != 'Addition'
			  order by sl_uuid, date
		
		) AS b
		
	on a.sl_uuid = b.sl_uuid
	where a.etl_date = '%WINDOW_START_DATE%' and a.sl_status = 'Activated'
	)
group by sl_uuid

) as B
	
on A.sl_uuid = B.sl_uuid	
order by customer_life
