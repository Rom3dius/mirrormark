.PHONY: setup install-hooks install-deps baseline check-secrets

# Set up everything except the .pre-commit-config.yaml file
setup: install-deps install-hooks baseline
	@echo "✅ Setup complete. Don't forget to add .pre-commit-config.yaml!"

# Install Python dependencies globally (optional: use venv)
install-deps:
	@echo "📦 Installing pre-commit and detect-secrets..."
	pip install pre-commit detect-secrets

# Install git hook using pre-commit
install-hooks:
	@echo "🔧 Installing git pre-commit hook..."
	pre-commit install

# Create a secrets baseline if it doesn't exist
baseline:
	@if [ ! -f .secrets.baseline ]; then \
		echo "🔐 Creating new .secrets.baseline..."; \
		detect-secrets scan > .secrets.baseline; \
	else \
		echo "ℹ️  .secrets.baseline already exists. Skipping."; \
	fi

# Run a manual check for new secrets
check-secrets:
	pre-commit run detect-secrets --all-files


