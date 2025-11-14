"""
E2E Testing with Playwright for Blue-Green Canary Deployment
Specific IP-based testing for office validation and automated testing
"""

import pytest
import asyncio
import os
import sys
from playwright.async_api import async_playwright, Page, Browser, BrowserContext
from typing import Optional
import requests
import time


class BlueGreenE2ETests:
    """E2E Test suite for Blue-Green deployment validation"""

    def __init__(self, base_url: str, environment: str, target_color: str):
        self.base_url = base_url.rstrip('/')
        self.environment = environment
        self.target_color = target_color
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None

    async def setup_browser(self, headless: bool = True):
        """Setup Playwright browser"""
        playwright = await async_playwright().start()

        # Launch browser with specific settings
        self.browser = await playwright.chromium.launch(
            headless=headless,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )

        # Create context with real user-agent
        self.context = await self.browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            viewport={'width': 1920, 'height': 1080}
        )

        # Create page
        self.page = await self.context.new_page()

        # Enable request/response logging
        self.page.on('request', lambda request: print(f"→ {request.method} {request.url}"))
        self.page.on('response', lambda response: print(f"← {response.status} {response.url}"))

    async def teardown_browser(self):
        """Cleanup browser resources"""
        if self.page:
            await self.page.close()
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()

    async def test_health_endpoint(self):
        """Test basic health endpoint"""
        print(f"Testing health endpoint: {self.base_url}/health.php")

        response = await self.page.goto(f"{self.base_url}/health.php")
        assert response.status == 200, f"Health endpoint returned {response.status}"

        # Check for specific health indicators
        content = await self.page.content()
        assert "OK" in content or "healthy" in content.lower(), "Health endpoint doesn't indicate healthy status"

        print("✅ Health endpoint test passed")

    async def test_main_page_load(self):
        """Test main application page loading"""
        print(f"Testing main page: {self.base_url}/")

        response = await self.page.goto(f"{self.base_url}/", wait_until='domcontentloaded')
        assert response.status == 200, f"Main page returned {response.status}"

        # Wait for page to be fully loaded
        await self.page.wait_for_load_state('networkidle')

        # Check page title
        title = await self.page.title()
        assert title, "Page title is empty"

        print(f"✅ Main page loaded successfully: {title}")

    async def test_application_functionality(self):
        """Test core application functionality"""
        print("Testing application functionality...")

        # Navigate to main page
        await self.page.goto(f"{self.base_url}/")

        # Example: Test login functionality (customize based on your app)
        # login_button = await self.page.query_selector('button[type="submit"]')
        # if login_button:
        #     await login_button.click()
        #     await self.page.wait_for_selector('.dashboard', timeout=5000)

        # Example: Test search functionality
        # search_input = await self.page.query_selector('input[name="search"]')
        # if search_input:
        #     await search_input.fill('test query')
        #     await search_input.press('Enter')
        #     await self.page.wait_for_selector('.search-results')

        # Check for any JavaScript errors
        errors = []
        self.page.on('pageerror', lambda error: errors.append(str(error)))

        # Wait a bit to catch any delayed errors
        await asyncio.sleep(2)

        if errors:
            print(f"⚠️ JavaScript errors detected: {errors}")
        else:
            print("✅ No JavaScript errors detected")

    async def test_api_endpoints(self):
        """Test API endpoints if available"""
        print("Testing API endpoints...")

        # Test common API endpoints
        api_endpoints = [
            '/api/status',
            '/api/version',
            '/api/health'
        ]

        for endpoint in api_endpoints:
            try:
                response = await self.page.goto(f"{self.base_url}{endpoint}")
                if response.status == 200:
                    content = await self.page.content()
                    print(f"✅ API endpoint {endpoint}: {response.status}")
                else:
                    print(f"ℹ️ API endpoint {endpoint}: {response.status} (may not exist)")
            except Exception as e:
                print(f"ℹ️ API endpoint {endpoint}: Not available")

    async def test_performance_metrics(self):
        """Test page performance metrics"""
        print("Testing performance metrics...")

        # Navigate to main page and measure performance
        start_time = time.time()
        response = await self.page.goto(f"{self.base_url}/", wait_until='domcontentloaded')
        load_time = time.time() - start_time

        print(f"Page load time: {load_time:.2f}s")

        # Performance assertions
        assert load_time < 10.0, f"Page load time too slow: {load_time:.2f}s"
        assert response.status == 200, f"Page returned {response.status}"

        # Check for performance timing if available
        try:
            timing = await self.page.evaluate("""
                () => {
                    const navigation = performance.getEntriesByType('navigation')[0];
                    return {
                        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
                        loadComplete: navigation.loadEventEnd - navigation.loadEventStart
                    };
                }
            """)
            print(f"DOM Content Loaded: {timing['domContentLoaded']:.2f}ms")
            print(f"Load Complete: {timing['loadComplete']:.2f}ms")
        except Exception as e:
            print(f"Could not get performance timing: {e}")

        print("✅ Performance test completed")

    async def test_responsive_design(self):
        """Test responsive design on different screen sizes"""
        print("Testing responsive design...")

        # Test different viewport sizes
        viewports = [
            {'width': 1920, 'height': 1080, 'name': 'Desktop'},
            {'width': 1024, 'height': 768, 'name': 'Tablet'},
            {'width': 375, 'height': 667, 'name': 'Mobile'}
        ]

        for viewport in viewports:
            await self.page.set_viewport_size({
                'width': viewport['width'],
                'height': viewport['height']
            })

            response = await self.page.goto(f"{self.base_url}/")
            assert response.status == 200, f"Page failed on {viewport['name']} viewport"

            # Wait for layout to stabilize
            await asyncio.sleep(1)

            print(f"✅ {viewport['name']} viewport test passed")

    async def run_all_tests(self):
        """Run all E2E tests"""
        try:
            await self.setup_browser()

            print(f"Starting E2E tests for {self.target_color} environment")
            print(f"Base URL: {self.base_url}")
            print("=" * 60)

            # Run individual tests
            await self.test_health_endpoint()
            await self.test_main_page_load()
            await self.test_application_functionality()
            await self.test_api_endpoints()
            await self.test_performance_metrics()
            await self.test_responsive_design()

            print("=" * 60)
            print("✅ All E2E tests completed successfully!")

        except Exception as e:
            print(f"❌ E2E test failed: {e}")
            raise
        finally:
            await self.teardown_browser()


# Pytest fixtures and test functions
@pytest.fixture
async def test_runner():
    """Pytest fixture for test runner"""
    base_url = os.getenv('BASE_URL', 'http://localhost')
    environment = os.getenv('ENVIRONMENT', 'poc')
    target_color = os.getenv('TARGET_COLOR', 'green')

    runner = BlueGreenE2ETests(base_url, environment, target_color)
    yield runner


@pytest.mark.asyncio
async def test_health_check(test_runner):
    """Pytest test for health check"""
    await test_runner.setup_browser()
    try:
        await test_runner.test_health_endpoint()
    finally:
        await test_runner.teardown_browser()


@pytest.mark.asyncio
async def test_main_functionality(test_runner):
    """Pytest test for main functionality"""
    await test_runner.setup_browser()
    try:
        await test_runner.test_main_page_load()
        await test_runner.test_application_functionality()
    finally:
        await test_runner.teardown_browser()


@pytest.mark.asyncio
async def test_performance(test_runner):
    """Pytest test for performance"""
    await test_runner.setup_browser()
    try:
        await test_runner.test_performance_metrics()
    finally:
        await test_runner.teardown_browser()


@pytest.mark.asyncio
async def test_full_suite(test_runner):
    """Pytest test for full E2E suite"""
    await test_runner.run_all_tests()


# Direct execution support
async def main():
    """Direct execution main function"""
    import argparse

    parser = argparse.ArgumentParser(description='Blue-Green E2E Testing')
    parser.add_argument('--base-url', required=True, help='Base URL for testing')
    parser.add_argument('--environment', default='poc', help='Environment name')
    parser.add_argument('--target', default='green', help='Target color (blue/green)')
    parser.add_argument('--headless', action='store_true', help='Run browser in headless mode')

    args = parser.parse_args()

    # Set environment variables for tests
    os.environ['BASE_URL'] = args.base_url
    os.environ['ENVIRONMENT'] = args.environment
    os.environ['TARGET_COLOR'] = args.target

    # Run tests
    runner = BlueGreenE2ETests(args.base_url, args.environment, args.target)
    await runner.run_all_tests()


if __name__ == '__main__':
    asyncio.run(main())
