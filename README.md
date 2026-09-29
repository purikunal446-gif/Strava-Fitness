# Strava Fitness Analytics – Final Submission

## Files
- `Strava_Fitness_MySQL_Analysis.sql` — MySQL database setup, cleaning layer, data-quality checks, business analysis and dashboard-ready views.
- `app.py` — Streamlit dashboard.
- `data/` — three source CSVs used by the dashboard.
- `requirements.txt` — Python packages.

## Dashboard
Run:
```bash
pip install -r requirements.txt
streamlit run app.py
```

## Dashboard layout
1. KPI cards: active users, average steps, calories, active minutes, sedentary minutes.
2. Daily steps trend.
3. Weekday activity pattern.
4. Activity intensity mix.
5. Steps vs calories relationship.
6. Sleep distribution and sleep/activity relationship.
7. Key business takeaways.

## MySQL
Open `Strava_Fitness_MySQL_Analysis.sql` in MySQL Workbench.
Update the three `LOAD DATA LOCAL INFILE` paths to your local CSV locations, then run the file section by section.

## Business context
The analysis follows the Bellabeat-style smart-device case study supplied with the project: understand how users interact with wellness devices and translate activity/sleep behaviour into marketing opportunities.
