# Задание:


- Необходимо ознакомиться с открытой API https://github.com/SK-EID/MID 
- Описать процесс аутентификации пользователей для последующей интеграции клиентского бизнес приложения с данным сервисом.
  
  **Ожидаемый результат**: UML Sequence Diagram описывающая взаимодействие:
- Клиентского мобильного приложения
- Бэкенд-сервиса для обращения к API MobileID
- API MobileID
- Базы данных для сохранения полученных результатов аутентификации пользователей

Примером клиентского бизнес приложения может выступать, например, приложение доставки еды, требующее от пользователей
обязательного прохождения аутентификации в одном из сторонних сервисов.


# Реализация:
<img width="1648" height="797" alt="image" src="https://github.com/user-attachments/assets/a83fb2ba-bce3-4103-9991-8347b4440ecf" />
<img width="1648" height="759" alt="image" src="https://github.com/user-attachments/assets/aa6fbe37-dd60-4977-ab80-2594e23ceeb1" />






## uml:
@startuml
title MobileID Authentication Flow
skinparam wrapWidth 250
participant "App" as App
participant "Backend" as Backend
participant "MobileID API" as MID
database "DB" as DB
participant "OCSP" as OCSP
autonumber

== 1. Старт аутентификации ==

App -> Backend: POST /auth/mid/init\n{ phone: "+372...", idempotency_key }

activate Backend
Backend -> Backend: 1. Генерируем hash (SHA-256)\n2. Считаем verification_code (4 цифры)\n3. Сохраняем nonce + timestamp

Backend -> MID: POST /authentication\n{ phone, hash, hashType:"SHA256",\n  relyingPartyUUID, Name,\n  displayText: "Войти в FoodApp?" }
activate MID

MID --> Backend: 200 { sessionID: "abc123" }
deactivate MID

Backend -> DB: INSERT auth_sessions\n{ session_id, status:"RUNNING",\n  hash_b64, nonce,\n  expires_at: NOW()+5min }
activate DB
DB --> Backend
deactivate DB

Backend --> App: 202 { session_id, verification_code:"1462" }
deactivate Backend

App -> App: Показываем: "Код: 1462"

== 2. Пользователь вводит код ==

note over MID: MID: Пользователь вводит PIN на телефоне
MID -> MID: SIM подписывает hash закрытым ключом

== 3. Опрос статуса (Long Polling) ==

App -> MID: GET /authentication/session/{sessionID}?timeoutMs=30000
activate MID

alt ещё ждём
    MID --> App: { state:"RUNNING" }
else готово
    MID --> App: { state:"COMPLETE", result:"OK" OR "USER_CANCELLED" OR "TIMEOUT",\n  signature?, cert? }
    break
end
deactivate MID

== 4. Обработка результата + OCSP ==

alt result == "OK"
    Backend -> Backend: Проверка подписи над исходным hash\nВалидация сертификата: срок, цепочка до CA
    
    Backend -> OCSP: POST OCSP request\n{ cert_serial, issuer_hash }
    activate OCSP
    OCSP --> Backend: { status: "good" | "revoked" | "unknown" }
    deactivate OCSP
    
    alt OCSP status == "good"
        Backend -> Backend: Сверка nonce (защита от replay)\nИзвлечение identity из cert.subject
        
        Backend -> DB: UPDATE auth_sessions\nSET status="SUCCESS", user_id=?, cert_serial=?
        activate DB
        DB --> Backend
        deactivate DB
        
        Backend -> DB: INSERT audit_logs\n{ event:"AUTH_FAILED", error_code:result }
        activate DB
        DB --> Backend
        deactivate DB
        
        Backend -> Backend: Генерация JWT access_token (exp=1h)\nrefresh_token -> хэш Argon2id + device binding
        
        Backend --> App: 200 { access_token, refresh_token, user_id }
        deactivate Backend
        
        App -> App: Сохраняем в SecureStorage
        
    else OCSP in ["revoked", "unknown"]
        Backend -> DB: UPDATE auth_sessions\nSET status="FAILED", error_code=result
        activate DB
        DB --> Backend
        deactivate DB
        
        Backend -> DB: INSERT audit_logs\n{ event:"CERT_REVOKED", ip, trace_id }
        activate DB
        DB --> Backend
        deactivate DB
        
        Backend --> App: 403 { error: "CERT_REVOKED",\n  retry_hint:"Обратитесь в поддержку" }
        deactivate Backend
    end
    
else result in ["USER_CANCELLED", "TIMEOUT", "NOT_MID_CLIENT"]
    Backend -> DB: UPDATE auth_sessions\nSET status="FAILED", error_code=result
    activate DB
    DB --> Backend
    deactivate DB
    
    Backend -> DB: INSERT audit_logs\n{ event:"AUTH_FAILED", error_code:result }
    activate DB
    DB --> Backend
    deactivate DB
    
    Backend --> App: 401 { error: result,\n  retry_hint:"Попробуйте снова" }
    deactivate Backend
end

note right of DB
  • auth_sessions: TTL 5 мин, индекс по session_id
  • refresh_tokens: хэш (Argon2id), привязка к device_fingerprint
  • audit_logs: без phone/IDN, IP маскируется (/24), хранение ≤12 мес
  • Шифрование at rest: AES-256 (TDE)
  • Доступ: роль app_user, только необходимые права
end note

@enduml
