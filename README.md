# SkillDuel v0.6 - Map Select & Terrain Effects

## 새 게임 흐름
메인 → 난이도 선택 → 캐릭터 선택 → **맵 선택** → 전투 → 결과

## 맵 3종

### 1. ARCANE RIVER / 아케인 강가
- 기존 기본 맵
- 특수 지형 없음
- 순수 캐릭터/스킬 대결용

### 2. RAIN RUINS / 비 내리는 폐허
- 화면 전체 비 연출
- 상/하 진영 곳곳에 물웅덩이
- 물웅덩이 안에 들어가면 플레이어/AI 모두 이동속도 45% 감소
- HUD에 `PUDDLE 이동속도 감소` 표시

### 3. SCORCHED GORGE / 작열 협곡
- 붉고 건조한 협곡 분위기
- 상/하 진영 곳곳에 열기 지대
- 열기 지대에 들어가면 플레이어/AI 모두 0.5초마다 4 피해
- HUD에 `HEAT 지속 피해` 표시
- 열기 구역이 맥동하고 아지랑이 선이 움직임

## 공정성
맵 지형 효과는 플레이어뿐 아니라 CPU에게도 동일하게 적용됩니다.

## 기존 v0.5 유지
- 캐릭터별 다른 Q/E/Shift/R
- 캐릭터 선택 UI / 스킬 아이콘
- 궁극기 배너
- 난이도별 AI
- 전적 저장
- 결과→메인 복귀 시 캐릭터/투사체 정리


## v0.7 추가

### SERA E - DEFLECT
- 기존 X 검기를 삭제
- 0.65초 동안 주변 적 투사체를 튕겨냄
- 되받아친 투사체는 상대편을 공격하며 피해량 20% 증가
- SERA CPU도 동일한 튕겨내기 사용 가능

### FROZEN PASS
- 기존 `SCORCHED GORGE` 삭제
- 설원/눈보라 맵으로 교체
- 곳곳의 빙판에 들어가면 속도는 조금 올라가지만 급정지와 방향전환이 어려워짐
- CPU에도 동일하게 적용

### River Heal Pack
- 모든 맵 중앙 강에 약 10초마다 힐팩 출현
- 힐팩은 좌→우 / 우→좌 번갈아 강을 가로질러 이동
- 플레이어 또는 CPU가 투사체로 먼저 맞히면 해당 진영이 35 HP 회복
- HUD에서 다음 힐팩 출현 시간을 확인 가능


## v0.8 - AI & Combat Feel

### 난이도별 AI 인지능력
- 초급: 느린 판단, 예측 조준 없음, 힐팩/투사체 대응이 매우 낮음
- 중급: 플레이어 이동을 일부 예측, 낮은 HP에서 힐팩 사격, 위험 탄 회피, SERA 반사 판단
- 상급: 높은 빈도의 상황 판단, 이동 예측 조준, 힐팩 회복/차단 판단, 위험 투사체 회피, SERA 반응형 튕겨내기, 궁극기 타이밍 판단
- 비맵에서는 중급/상급 AI가 물웅덩이를 이동 목표로 선택하지 않도록 개선

### 캐릭터 차별화 강화
- ARIA E: 6개 곡선 파편으로 공간을 넓게 봉쇄하는 Arcane Spiral
- LYRA Q: 초고속 장거리 2회 관통 Piercing Shot
- SERA E: 기존 Deflect 유지. 중/상급 CPU는 위험 투사체를 보고 반응형으로 사용
- CPU도 Q / E / Shift / R을 상황에 따라 사용

### 타격감
- 피격 순간 화면 흔들림
- 큰 피해일수록 더 강한 흔들림/화면 플래시
- 피격 위치에 픽셀 파편 + 데미지 숫자 표시
- Player / CPU 피격 플래시


## v0.9 - Polish Update

### Sound
- UI click
- basic attack
- skill cast
- hit
- ultimate
- heal pack
- heal pack warning
- deflect
- 외부 음원 대신 프로젝트에 포함된 간단한 chiptune-style WAV 사용

### Character Animation
- Idle bob
- Move bob + slight tilt
- Cast recoil
- Hit flash
- Defeat tilt
- 현재 코드 기반 픽셀 캐릭터 구조를 유지한 상태에서 동작감 추가

### Ultimate Presentation
- 기존 ULTIMATE 배너 유지
- 캐릭터 색상 기반 확장 링과 방사형 레이 추가
- 큰 타격은 기존 v0.8의 화면 흔들림/플래시와 연동

### Heal Pack
- 등장 2초 전 `HEAL PACK INCOMING`
- 경고 SFX 추가
- 기존 10초 주기 / 먼저 맞힌 진영 +35 HP 유지

### AI Personality
- ARIA: 중거리 유지 + 공간 장악형
- LYRA: 최대한 거리 벌리기 + 원거리 압박형
- SERA: 더 적극적으로 접근 + Deflect 활용형
- 기존 난이도별 인지/예측/회피/힐팩 판단 로직 유지
