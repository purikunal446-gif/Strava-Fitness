import os
import pandas as pd
import plotly.express as px
import streamlit as st

st.set_page_config(page_title="Strava Fitness Analytics", page_icon="🏃", layout="wide")

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

@st.cache_data
def load_data():
    activity = pd.read_csv(os.path.join(DATA_DIR, "dailyActivity_merged.csv"))
    sleep = pd.read_csv(os.path.join(DATA_DIR, "sleepDay_merged.csv"))
    weight = pd.read_csv(os.path.join(DATA_DIR, "weightLogInfo_merged.csv"))

    activity["ActivityDate"] = pd.to_datetime(activity["ActivityDate"])
    sleep["SleepDay"] = pd.to_datetime(sleep["SleepDay"])
    weight["Date"] = pd.to_datetime(weight["Date"])

    activity["ActiveMinutes"] = (
        activity["VeryActiveMinutes"]
        + activity["FairlyActiveMinutes"]
        + activity["LightlyActiveMinutes"]
    )
    activity["Weekday"] = activity["ActivityDate"].dt.day_name()
    activity["Month"] = activity["ActivityDate"].dt.to_period("M").astype(str)

    return activity, sleep, weight

activity, sleep, weight = load_data()

st.title("Strava Fitness Analytics Dashboard")
st.caption("Smart-device activity, sleep and wellness behaviour | Fitbit sample dataset")

# Sidebar filters
st.sidebar.header("Dashboard Filters")
min_date = activity["ActivityDate"].min().date()
max_date = activity["ActivityDate"].max().date()
date_range = st.sidebar.date_input("Activity period", (min_date, max_date))

if isinstance(date_range, tuple) and len(date_range) == 2:
    start_date, end_date = pd.to_datetime(date_range[0]), pd.to_datetime(date_range[1])
else:
    start_date, end_date = pd.to_datetime(min_date), pd.to_datetime(max_date)

users = sorted(activity["Id"].unique())
selected_users = st.sidebar.multiselect("Customer", users, default=[])

filtered = activity[
    (activity["ActivityDate"].between(start_date, end_date))
]
if selected_users:
    filtered = filtered[filtered["Id"].isin(selected_users)]

# KPI layer
c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("Active Users", f"{filtered['Id'].nunique():,}")
c2.metric("Avg Daily Steps", f"{filtered['TotalSteps'].mean():,.0f}")
c3.metric("Avg Calories", f"{filtered['Calories'].mean():,.0f}")
c4.metric("Avg Active Minutes", f"{filtered['ActiveMinutes'].mean():,.0f}")
c5.metric("Avg Sedentary Minutes", f"{filtered['SedentaryMinutes'].mean():,.0f}")

st.divider()

# Trend section
left, right = st.columns(2)

daily = filtered.groupby("ActivityDate", as_index=False).agg(
    AvgSteps=("TotalSteps", "mean"),
    AvgCalories=("Calories", "mean"),
    ActiveUsers=("Id", "nunique")
)

with left:
    fig = px.line(daily, x="ActivityDate", y="AvgSteps",
                  markers=True, title="Daily Average Steps")
    fig.update_layout(yaxis_title="Steps", xaxis_title="")
    st.plotly_chart(fig, use_container_width=True)

with right:
    weekday_order = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
    weekday = filtered.groupby("Weekday", as_index=False)["TotalSteps"].mean()
    weekday["Weekday"] = pd.Categorical(weekday["Weekday"], categories=weekday_order, ordered=True)
    weekday = weekday.sort_values("Weekday")
    fig = px.bar(weekday, x="Weekday", y="TotalSteps",
                 title="Average Steps by Weekday")
    fig.update_layout(yaxis_title="Steps", xaxis_title="")
    st.plotly_chart(fig, use_container_width=True)

# Activity behaviour
left, right = st.columns(2)

with left:
    activity_mix = pd.DataFrame({
        "Intensity": ["Very Active", "Fairly Active", "Lightly Active", "Sedentary"],
        "Minutes": [
            filtered["VeryActiveMinutes"].mean(),
            filtered["FairlyActiveMinutes"].mean(),
            filtered["LightlyActiveMinutes"].mean(),
            filtered["SedentaryMinutes"].mean()
        ]
    })
    fig = px.bar(activity_mix, x="Intensity", y="Minutes",
                 title="Average Daily Time by Activity Level")
    st.plotly_chart(fig, use_container_width=True)

with right:
    fig = px.scatter(
        filtered,
        x="TotalSteps",
        y="Calories",
        size="ActiveMinutes",
        hover_data=["Id", "ActivityDate"],
        title="Steps vs Calories"
    )
    st.plotly_chart(fig, use_container_width=True)

# Sleep section
st.subheader("Sleep & Recovery")
sleep_filtered = sleep[
    (sleep["SleepDay"] >= start_date) &
    (sleep["SleepDay"] <= end_date)
].copy()

if selected_users:
    sleep_filtered = sleep_filtered[sleep_filtered["Id"].isin(selected_users)]

if not sleep_filtered.empty:
    sleep_filtered["SleepHours"] = sleep_filtered["TotalMinutesAsleep"] / 60
    sleep_join = sleep_filtered.merge(
        filtered[["Id","ActivityDate","TotalSteps","ActiveMinutes"]],
        left_on=["Id","SleepDay"],
        right_on=["Id","ActivityDate"],
        how="inner"
    )
    a, b = st.columns(2)
    with a:
        fig = px.histogram(sleep_filtered, x="SleepHours", nbins=12,
                           title="Sleep Duration Distribution")
        st.plotly_chart(fig, use_container_width=True)
    with b:
        if not sleep_join.empty:
            fig = px.scatter(
                sleep_join, x="SleepHours", y="TotalSteps",
                hover_data=["Id", "SleepDay"],
                title="Sleep Duration vs Steps"
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No matching activity/sleep dates for the selected filters.")
else:
    st.info("No sleep records for the selected filters.")

# Business insights
st.subheader("Key Takeaways")
avg_steps = filtered["TotalSteps"].mean()
avg_sleep = sleep_filtered["TotalMinutesAsleep"].mean() / 60 if not sleep_filtered.empty else None
best_day = filtered.groupby("Weekday")["TotalSteps"].mean().idxmax()
low_activity_share = (filtered["TotalSteps"] < 5000).mean() * 100

ins1, ins2 = st.columns(2)
with ins1:
    st.write(f"• Average daily movement is **{avg_steps:,.0f} steps**.")
    st.write(f"• **{best_day}** has the highest average step count in the selected data.")
with ins2:
    st.write(f"• **{low_activity_share:.1f}%** of tracked activity days are below 5,000 steps.")
    if avg_sleep:
        st.write(f"• Average recorded sleep is **{avg_sleep:.1f} hours**.")

st.caption("Analytical note: this dataset represents a sample of smart-device users, so findings describe the observed sample rather than the entire population.")
