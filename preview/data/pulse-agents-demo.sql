SELECT
  *
FROM (
  SELECT
    ac.name AS account_name,
    su.name AS survey_name,
    ac.identifier,
    su.id AS survey_id,
    ac.id AS account_id,
    su.status AS survey_status,
    CASE WHEN su.status=0 THEN 'Draft' WHEN su.status=1 THEN 'Live' WHEN su.status=2 THEN 'Paused'
         WHEN su.status=3 THEN 'Complete' WHEN su.status=4 THEN 'Archived' END AS survey_status_name,
    su.survey_type,
    CASE WHEN su.survey_type=0 THEN 'Docked Widget' WHEN su.survey_type=1 THEN 'Inline'
         WHEN su.survey_type=2 THEN 'Top Bar' WHEN su.survey_type=3 THEN 'Bottom Bar'
         WHEN su.survey_type=4 THEN 'Fullscreen' ELSE 'Unknown' END AS survey_type_name,
    su.inline_target_selector,
    su.custom_css AS survey_css,
    th.id AS theme_id,
    th.name AS theme,
    th.css AS theme_css,
    COALESCE(t.tags,'') AS survey_tags,
    EXISTS (
      SELECT 1
      FROM applied_survey_tags ast
      JOIN survey_tags st ON st.id=ast.survey_tag_id
      WHERE ast.survey_id=su.id
        AND st.name ILIKE 'Agent'         -- exact tag match, case-insensitive
    ) AS survey_tag_agent
  FROM surveys su
  JOIN accounts ac ON su.account_id=ac.id
  LEFT JOIN themes th ON th.id=su.theme_id
  LEFT JOIN LATERAL (
    SELECT STRING_AGG(st.name,'; ' ORDER BY st.name) AS tags
    FROM applied_survey_tags ast
    JOIN survey_tags st ON st.id=ast.survey_tag_id
    WHERE ast.survey_id=su.id
  ) t ON TRUE
  WHERE TRUE
) s
WHERE s.survey_tag_agent = TRUE;