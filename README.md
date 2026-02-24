# 🚨 얘진상 — 진상 손님 사전 차단 시스템

유흥업소 사장님을 위한 진상 손님 공유 & 수신 전화 경고 앱

[![Download APK](https://img.shields.io/badge/Download-APK-red?style=for-the-badge)](https://github.com/LeeJaeBae/yae-jinsang/releases/latest/download/app-release.apk)
[![Landing Page](https://img.shields.io/badge/Landing-Page-black?style=for-the-badge)](https://jinsang.thebespoke.team)

---

## 📱 주요 기능

- **수신 전화 실시간 조회** — 전화 오면 자동으로 진상 DB 매칭
- **경고 오버레이** — 진상 감지 시 화면 위 경고 표시, 미등록 번호도 바로 등록 가능
- **태그 시스템** — 폭력/먹튀/행패/스토커/블랙 + 직접 입력
- **연락처 일괄 등록** — 주소록에서 바로 진상 등록
- **태그 관리** — 검색, 필터, 수정, 삭제
- **추천 시스템** — 추천코드로 1개월 무료 연장
- **업소 프로필** — 업소명, 지역, 업종 관리
- **앱 업데이트 알림** — 새 버전 자동 감지

## 🔒 개인정보 보호

- 전화번호는 **SHA-256 해시**로만 저장, 원본 번호 절대 저장 안 함
- 전화 **차단하지 않음** — 경고만 표시, 판단은 사장님이
- 폰 인증(OTP)으로 본인 확인

## 🛠 기술 스택

- **앱**: Flutter (Android-only)
- **백엔드**: Supabase (PostgreSQL + Auth + Realtime)
- **인증**: Phone OTP (Twilio)
- **랜딩**: Next.js + Tailwind CSS ([yae-jinsang-web](https://github.com/LeeJaeBae/yae-jinsang-web))

## 💰 가격

| 플랜 | 가격 | 비고 |
|------|------|------|
| 월간 | 49,000원 | |
| 연간 | 529,200원 | 10% 할인 |
| 추천 보상 | 1개월 무료 | 추천 1건당 |

---

## 📋 릴리즈 노트

### v1.0.0 (2026.02.24) — 정식 출시

#### 🚀 핵심 기능
- 전화 수신 시 진상 DB 실시간 조회 (CallScreeningService)
- 진상 감지 경고 오버레이 + 미등록 번호 바로 등록
- 태그 등록/관리 (폭력, 먹튀, 행패, 스토커, 블랙, 직접입력)
- 연락처에서 일괄 진상 등록 (이름/메모 기반 자동 태그 감지)
- 태그 관리 화면 (검색, 필터, 수정, 삭제)

#### 👤 계정
- 폰 인증(OTP) 회원가입/로그인
- 업소 프로필 (업소명, 지역, 업종)
- 로그아웃

#### 💳 구독
- 구독 상태 실시간 반영 (Supabase Realtime)
- 페이월 화면 (월간/연간 가격 표시)

#### 🎁 추천 시스템
- 추천코드 자동 생성 (YJ-XXXX)
- 추천인 → 1개월 무료 연장
- 피추천인 → 첫 달 50% 할인
- 추천 현황 조회 + 카톡 공유

#### 🔧 기타
- 앱 내 업데이트 자동 체크 (GitHub Releases)
- 앱 아이콘 통일 (빨간 방패)
- 다크 테마 UI

---

## 📞 문의

- **이메일**: hello@thebespoke.team
- **웹사이트**: https://jinsang.thebespoke.team

## 📄 법적 고지

- [이용약관](https://jinsang.thebespoke.team/terms)
- [개인정보처리방침](https://jinsang.thebespoke.team/privacy)

---

**더 비스포크** | © 2026
