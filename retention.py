# %% [markdown]
# # Mobile Game — Player Retention & Early Engagement Analysis
# Pipeline đầy đủ trong 1 file: EDA -> Chuẩn bị dữ liệu -> Trực quan hóa
# Phạm vi: cohort đăng ký 2020-01-01 trở đi, đủ 7 ngày quan sát

# %%
# ===== 0. IMPORT + CONFIG =====
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
sns.set_style('whitegrid')

START_DATE = pd.Timestamp('2020-01-01')

# %%
# ===== 1. ĐỌC DỮ LIỆU  =====
reg = pd.read_csv('reg_data.csv', sep=';')
auth = pd.read_csv('auth_data.csv', sep=';')

# %%
# ===== 2. EDA — CHECK DATA QUALITY =====
def kiem_tra(df, ten):
    print(f"\n===== {ten} =====")
    print("Shape:", df.shape)
    print("Dtypes:\n", df.dtypes.to_string())
    print("Null:\n", df.isnull().sum().to_string())
    print("Dòng trùng hoàn toàn:", df.duplicated().sum())

kiem_tra(reg, "reg_data")
kiem_tra(auth, "auth_data")
print("\nreg: uid trùng?", reg['uid'].duplicated().sum(),
      "| unique uid:", reg['uid'].nunique(), "/", len(reg))

# %%
# ===== 3. CONVERT timestamp + EDA phân bố thời gian (chẩn đoán) =====
# Unix timestamp (giây) -> ngày; .dt.normalize() bỏ giờ, giữ ngày
reg['registration_date'] = pd.to_datetime(reg['reg_ts'], unit='s').dt.normalize()
auth['activity_date'] = pd.to_datetime(auth['auth_ts'], unit='s').dt.normalize()

print("reg_ts range :", reg['registration_date'].min().date(), "->", reg['registration_date'].max().date())
print("auth_ts range:", auth['activity_date'].min().date(), "->", auth['activity_date'].max().date())

# Biểu đồ chẩn đoán: phân bố ĐĂNG KÝ theo năm và phân bố theo THÁNG trong 2020
fig, ax = plt.subplots(1, 2, figsize=(13, 4))
reg['registration_date'].dt.year.value_counts().sort_index().plot(
    kind='bar', ax=ax[0], color='#94a3b8')
ax[0].set_title('Đăng ký theo NĂM (toàn dữ liệu)')
ax[0].set_xlabel('Năm'); ax[0].set_ylabel('Số user')

reg2020 = reg[reg['registration_date'] >= START_DATE]
reg2020['registration_date'].dt.to_period('M').astype(str).value_counts().sort_index().plot(
    kind='bar', ax=ax[1], color='#2563eb')
ax[1].set_title('Đăng ký theo THÁNG (2020) — cần đều, không có cột đột biến')
ax[1].set_xlabel('Tháng'); ax[1].set_ylabel('Số user')
plt.tight_layout()
plt.savefig('chart0_timestamp_distribution.png', dpi=130)
plt.show()

# %%
# ===== 4. CHUẨN BỊ DỮ LIỆU NỀN =====
reg_users = reg[['uid', 'registration_date']].copy()
# 1 người login nhiều lần/ngày -> chỉ giữ NGÀY có hoạt động
auth_events = auth[['uid', 'activity_date']].drop_duplicates()

# Biên quan sát
last_activity_date = auth_events['activity_date'].max()
cutoff_date = last_activity_date - pd.Timedelta(days=7)   # cohort đủ 7 ngày

# Chốt tập cohort: đăng ký 2020 + đủ 7 ngày quan sát
# (mẫu số & tử số DÙNG CHUNG tập này -> tránh lệch mẫu số/tử số)
reg_complete = reg_users[
    (reg_users['registration_date'] >= START_DATE) &
    (reg_users['registration_date'] <= cutoff_date)
].copy()

# Hoạt động của đúng nhóm cohort trên
player_activity = auth_events.merge(reg_complete, on='uid', how='inner')
player_activity = player_activity[
    (player_activity['activity_date'] >= player_activity['registration_date']) &
    (player_activity['activity_date'] <= last_activity_date)   # guard biên dữ liệu
].copy()
player_activity['days_since_registration'] = (
    player_activity['activity_date'] - player_activity['registration_date']
).dt.days

# Chỉ giữ 7 ngày đầu
first7 = player_activity[player_activity['days_since_registration'].between(0, 7)].copy()

total_users = reg_complete['uid'].nunique()
print("Phạm vi cohort :", reg_complete['registration_date'].min().date(),
      "->", reg_complete['registration_date'].max().date())
print("Mốc chốt dữ liệu:", last_activity_date.date())
print("Tổng cohort     :", total_users)

# Lưu 2 bảng
reg_complete.to_csv('reg_complete.csv', index=False)
first7.to_csv('first_7d_complete.csv', index=False)

# %%
# ===== 5. BIỂU ĐỒ 1 — Retention curve D0->D7 =====
curve = first7.groupby('days_since_registration')['uid'].nunique().rename('active_users').reset_index()
curve['retention_pct'] = curve['active_users'] / total_users * 100
print("BẢNG 1 — Retention curve:")
print(curve.round(2).to_string(index=False))

plt.figure(figsize=(9, 5))
plt.plot(curve['days_since_registration'], curve['retention_pct'], marker='o', linewidth=2, color='#2563eb')
for x, y in zip(curve['days_since_registration'], curve['retention_pct']):
    plt.text(x, y + 1.5, f'{y:.1f}%', ha='center', fontsize=9)
plt.title('Retention Curve — 7 ngày đầu', fontsize=13, weight='bold')
plt.xlabel('Ngày sau đăng ký'); plt.ylabel('% còn hoạt động'); plt.ylim(0, 105)
plt.tight_layout(); plt.savefig('chart1_retention_curve.png', dpi=130); plt.show()

# %%
# ===== 6. BIỂU ĐỒ 2 — Drop-off giữa các ngày =====
curve['change_pp'] = curve['retention_pct'].diff()
drop = curve.dropna(subset=['change_pp']).copy()
drop['transition'] = 'D' + (drop['days_since_registration'] - 1).astype(str) + '→D' + drop['days_since_registration'].astype(str)
print("\nBẢNG 2 — Drop-off (pp):")
print(drop[['transition', 'change_pp']].round(2).to_string(index=False))

colors = ['#dc2626' if v < 0 else '#16a34a' for v in drop['change_pp']]
plt.figure(figsize=(9, 5))
plt.bar(drop['transition'], drop['change_pp'], color=colors)
for i, v in enumerate(drop['change_pp']):
    plt.text(i, v + (0.5 if v >= 0 else -1.5), f'{v:+.1f}', ha='center', fontsize=9)
plt.axhline(0, color='black', linewidth=0.8)
plt.title('Thay đổi retention giữa các ngày (pp)', fontsize=13, weight='bold')
plt.xlabel('Chuyển tiếp'); plt.ylabel('pp')
plt.tight_layout(); plt.savefig('chart2_dropoff.png', dpi=130); plt.show()

# %%
# ===== 7. BIỂU ĐỒ 3 — D7 retention theo SỐ NGÀY QUAY LẠI (D1-D6) =====
# Nhãn: retained_d7 = có hoạt động đúng D7
retained_uid = set(first7.loc[first7['days_since_registration'] == 7, 'uid'])

# Feature = số ngày QUAY LẠI trong D1-D6 (BỎ D0 vì gần như user nào cũng active D0
# -> nếu tính cả D0 thì feature kém phân biệt; đồng thời D1-D6 không chứa ngày
#    nhãn D7 nên không bị data leakage).
returns = first7[first7['days_since_registration'].between(1, 6)]
return_days = returns.groupby('uid')['activity_date'].nunique().rename('return_days_d1_d6')
return_days = return_days.reset_index()   # reset_index cho tường minh trước khi merge

feat = reg_complete[['uid']].drop_duplicates().merge(return_days, on='uid', how='left')
feat['return_days_d1_d6'] = feat['return_days_d1_d6'].fillna(0).astype(int)
feat['retained_d7'] = feat['uid'].isin(retained_uid).astype(int)

per = feat.groupby('return_days_d1_d6').agg(
    players=('uid', 'count'),
    d7_retention_pct=('retained_d7', lambda s: s.mean() * 100)
).reset_index()
print("\nBẢNG 3 — D7 retention theo số ngày quay lại (D1-D6):")
print(per.round(2).to_string(index=False))

show = per[per['players'] >= 100]   # bỏ nhóm quá ít user
plt.figure(figsize=(9, 5))
plt.bar(show['return_days_d1_d6'].astype(str), show['d7_retention_pct'], color='#7c3aed')
for i, (v, n) in enumerate(zip(show['d7_retention_pct'], show['players'])):
    plt.text(i, v + 0.4, f'{v:.1f}%\n(n={n:,})', ha='center', fontsize=8)
plt.title('D7 retention theo số ngày quay lại trong D1-D6', fontsize=13, weight='bold')
plt.xlabel('Số ngày quay lại (D1-D6) — 0 = không quay lại trong D1-D6')
plt.ylabel('D7 retention (%)')
plt.tight_layout(); plt.savefig('chart3_engagement.png', dpi=130); plt.show()

# %%
# ===== 8. BIỂU ĐỒ 4 — Cohort heatmap (theo tháng) =====
first7['cohort_month'] = first7['registration_date'].dt.to_period('M').astype(str)
reg_complete['cohort_month'] = reg_complete['registration_date'].dt.to_period('M').astype(str)
denom = reg_complete.groupby('cohort_month')['uid'].nunique()

num = first7[first7['days_since_registration'].between(1, 7)] \
    .groupby(['cohort_month', 'days_since_registration'])['uid'].nunique().reset_index()
matrix = num.pivot(index='cohort_month', columns='days_since_registration', values='uid')
retention_matrix = matrix.div(denom, axis=0) * 100
retention_matrix.columns = ['D' + str(c) for c in retention_matrix.columns]
print("\nBẢNG 4 — Cohort heatmap:")
print(retention_matrix.round(1).to_string())

plt.figure(figsize=(9, 6))
sns.heatmap(retention_matrix, annot=True, fmt='.1f', cmap='YlOrRd', cbar_kws={'label': 'Retention (%)'})
plt.title('Cohort Retention Heatmap (theo tháng)', fontsize=13, weight='bold')
plt.xlabel('Ngày sau đăng ký'); plt.ylabel('Tháng đăng ký')
plt.tight_layout(); plt.savefig('chart4_cohort_heatmap.png', dpi=130); plt.show()

print("\nHOÀN TẤT. Lưu ý: đường cong retention KHÔNG giảm dần chuẩn —"
      " đặc tính dữ liệu synthetic (heatmap đồng đều giữa các tháng đã xác nhận"
      " không phải do cụm timestamp bất thường).")
