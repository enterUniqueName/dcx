<script>
	import { goto } from '$app/navigation';
	import { api } from '$lib/api';

	let email = '';
	let password = '';
	let mode = 'signin'; // 'signin' | 'signup'
	let error = '';
	let submitting = false;

	async function submit() {
		error = '';
		submitting = true;
		try {
			if (mode === 'signin') {
				await api.signIn(email, password);
			} else {
				const result = await api.signUp(email, password);
				if (result.session) {
					await api.initAuth();
				} else {
					error =
						'Account created — check your email to confirm, then sign in.';
					return;
				}
			}
			goto('/');
		} catch (e) {
			error = e.message;
		} finally {
			submitting = false;
		}
	}
</script>

<div class="login">
	<form class="card" onsubmit={(e) => { e.preventDefault(); submit(); }}>
		<h1>dcx</h1>
		<p class="subtitle">Property operations</p>

		<div class="field">
			<label for="email">Email</label>
			<input id="email" class="input" type="email" bind:value={email} required />
		</div>
		<div class="field">
			<label for="password">Password</label>
			<input
				id="password"
				class="input"
				type="password"
				bind:value={password}
				required
				minlength="6"
			/>
		</div>

		{#if error}<p class="error-text">{error}</p>{/if}

		<button class="btn btn-primary btn-block" type="submit" disabled={submitting}>
			{mode === 'signin' ? 'Sign in' : 'Create account'}
		</button>
		<button class="btn btn-block" type="button" onclick={() => mode = mode === 'signin' ? 'signup' : 'signin'}>
			{mode === 'signin' ? 'Need an account? Sign up' : 'Have an account? Sign in'}
		</button>
	</form>
</div>

<style>
	.login {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	form {
		width: 100%;
		max-width: 340px;
		display: grid;
		gap: 0.25rem;
	}
	h1 {
		margin: 0;
	}
	.subtitle {
		color: var(--text-muted);
		margin: 0 0 1rem;
	}
	.btn-block {
		width: 100%;
		justify-content: center;
	}
</style>
