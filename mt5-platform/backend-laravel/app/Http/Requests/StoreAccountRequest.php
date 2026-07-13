<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAccountRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;   // gate via route middleware (sanctum + policy)
    }

    public function rules(): array
    {
        return [
            'login'         => ['required', 'string', 'max:32'],
            'broker_server' => ['required', 'string', 'max:128'],
            'password'      => ['required', 'string', 'min:4', 'max:128'],
            'password_type' => ['nullable', Rule::in(['investor', 'master'])],
            'label'         => ['nullable', 'string', 'max:128'],
            'owner'         => ['nullable', 'string', 'max:128'],
            'license_id'    => ['nullable', 'integer'],

            // login must be unique per broker server (matches DB constraint)
            'broker_server_login_unique' => [
                function () {
                    $exists = \App\Models\TradingAccount::where('login', $this->login)
                        ->where('broker_server', $this->broker_server)
                        ->exists();
                    if ($exists) {
                        $this->validator->errors()->add('login', 'This login already exists for that broker server.');
                    }
                },
            ],
        ];
    }
}
