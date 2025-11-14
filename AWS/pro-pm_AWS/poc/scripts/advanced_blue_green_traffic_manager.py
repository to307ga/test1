#!/usr/bin/env python3
"""
Advanced Blue-Green Deployment Traffic Manager
Enhanced with flexible trigger conditions and IP-based canary deployment
"""

import boto3
import time
import json
import sys
import argparse
import ipaddress
from typing import Dict, List, Tuple, Optional
from botocore.exceptions import ClientError


class AdvancedBlueGreenTrafficManager:
    def __init__(self, region: str = 'ap-northeast-1'):
        """Initialize Advanced Blue-Green Traffic Manager"""
        self.cloudformation = boto3.client('cloudformation', region_name=region)
        self.elbv2 = boto3.client('elbv2', region_name=region)
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.region = region

    def get_stack_outputs(self, stack_name: str) -> Dict[str, str]:
        """Get CloudFormation stack outputs"""
        try:
            response = self.cloudformation.describe_stacks(StackName=stack_name)
            stack = response['Stacks'][0]

            outputs = {}
            if 'Outputs' in stack:
                for output in stack['Outputs']:
                    outputs[output['OutputKey']] = output['OutputValue']

            return outputs
        except ClientError as e:
            print(f"Error getting stack outputs for {stack_name}: {e}")
            return {}

    def update_listener_weights(self, listener_arn: str, blue_tg_arn: str,
                              green_tg_arn: str, blue_weight: int, green_weight: int) -> bool:
        """Update ALB listener rule weights for Blue-Green traffic distribution"""
        try:
            # Validate weights
            if blue_weight + green_weight != 100:
                print(f"Error: Weights must sum to 100. Blue: {blue_weight}, Green: {green_weight}")
                return False

            # Update listener default action with weighted routing
            self.elbv2.modify_listener(
                ListenerArn=listener_arn,
                DefaultActions=[
                    {
                        'Type': 'forward',
                        'ForwardConfig': {
                            'TargetGroups': [
                                {
                                    'TargetGroupArn': blue_tg_arn,
                                    'Weight': blue_weight
                                },
                                {
                                    'TargetGroupArn': green_tg_arn,
                                    'Weight': green_weight
                                }
                            ]
                        }
                    }
                ]
            )

            print(f"Updated traffic distribution - Blue: {blue_weight}%, Green: {green_weight}%")
            return True

        except ClientError as e:
            print(f"Error updating listener weights: {e}")
            return False

    def create_ip_based_canary_rule(self, listener_arn: str, target_group_arn: str,
                                   ip_addresses: List[str], rule_priority: int = 100) -> Optional[str]:
        """Create IP-based listener rule for canary deployment"""
        try:
            # Create condition for specific IP addresses
            conditions = []

            # Split IPs into CIDR blocks if needed
            ip_values = []
            for ip in ip_addresses:
                try:
                    # Check if it's already a CIDR
                    ipaddress.ip_network(ip, strict=False)
                    ip_values.append(ip)
                except ValueError:
                    # Convert single IP to /32 CIDR
                    try:
                        ipaddress.ip_address(ip)
                        ip_values.append(f"{ip}/32")
                    except ValueError:
                        print(f"Invalid IP address: {ip}")
                        continue

            if not ip_values:
                print("No valid IP addresses provided")
                return None

            conditions.append({
                'Field': 'source-ip',
                'SourceIpConfig': {
                    'Values': ip_values
                }
            })

            # Create the rule
            response = self.elbv2.create_rule(
                ListenerArn=listener_arn,
                Conditions=conditions,
                Priority=rule_priority,
                Actions=[
                    {
                        'Type': 'forward',
                        'TargetGroupArn': target_group_arn
                    }
                ]
            )

            rule_arn = response['Rules'][0]['RuleArn']
            print(f"Created IP-based canary rule: {rule_arn}")
            print(f"Target IPs: {ip_values}")

            return rule_arn

        except ClientError as e:
            print(f"Error creating IP-based rule: {e}")
            return None

    def delete_listener_rule(self, rule_arn: str) -> bool:
        """Delete a listener rule"""
        try:
            self.elbv2.delete_rule(RuleArn=rule_arn)
            print(f"Deleted listener rule: {rule_arn}")
            return True
        except ClientError as e:
            print(f"Error deleting rule: {e}")
            return False

    def check_target_group_health(self, target_group_arn: str) -> Tuple[int, int]:
        """Check target group health status"""
        try:
            response = self.elbv2.describe_target_health(TargetGroupArn=target_group_arn)

            healthy_count = 0
            total_count = 0

            for target in response['TargetHealthDescriptions']:
                total_count += 1
                if target['TargetHealth']['State'] == 'healthy':
                    healthy_count += 1

            return healthy_count, total_count

        except ClientError as e:
            print(f"Error checking target group health: {e}")
            return 0, 0

    def get_cloudwatch_metrics(self, load_balancer_name: str, metric_name: str,
                              minutes: int = 5) -> float:
        """Get CloudWatch metrics for monitoring"""
        try:
            end_time = time.time()
            start_time = end_time - (minutes * 60)

            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName=metric_name,
                Dimensions=[
                    {'Name': 'LoadBalancer', 'Value': load_balancer_name}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=60,
                Statistics=['Average', 'Sum']
            )

            if response['Datapoints']:
                if metric_name in ['HTTPCode_Target_5XX_Count', 'HTTPCode_Target_4XX_Count']:
                    return sum(dp['Sum'] for dp in response['Datapoints'])
                else:
                    return sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
            else:
                return 0.0

        except ClientError as e:
            print(f"Error getting CloudWatch metrics: {e}")
            return 0.0

    def validate_metrics(self, load_balancer_name: str,
                        error_threshold: float = 5.0,
                        response_time_threshold: float = 2.0) -> bool:
        """Validate metrics before proceeding to next step"""
        print("Validating metrics...")

        # Check error rate (5XX errors)
        error_count = self.get_cloudwatch_metrics(load_balancer_name, 'HTTPCode_Target_5XX_Count', 5)
        request_count = self.get_cloudwatch_metrics(load_balancer_name, 'RequestCount', 5)

        error_rate = (error_count / request_count * 100) if request_count > 0 else 0
        print(f"Error rate: {error_rate:.2f}% (threshold: {error_threshold}%)")

        if error_rate > error_threshold:
            print(f"❌ Error rate too high: {error_rate:.2f}%")
            return False

        # Check response time
        response_time = self.get_cloudwatch_metrics(load_balancer_name, 'TargetResponseTime', 5)
        print(f"Response time: {response_time:.3f}s (threshold: {response_time_threshold}s)")

        if response_time > response_time_threshold:
            print(f"❌ Response time too high: {response_time:.3f}s")
            return False

        print("✅ Metrics validation passed")
        return True

    def ip_based_canary_deployment(self, environment: str, application: str,
                                 canary_ips: List[str], target_environment: str) -> bool:
        """Perform IP-based canary deployment for specific users/testers"""

        print(f"Starting IP-based canary deployment to {target_environment}")
        print(f"Canary IPs: {canary_ips}")

        # Get stack information
        alb_stack_name = f"{environment}-{application}-alb-blue-green"
        blue_stack_name = f"{environment}-{application}-ec2-blue"
        green_stack_name = f"{environment}-{application}-ec2-green"

        alb_outputs = self.get_stack_outputs(alb_stack_name)
        blue_outputs = self.get_stack_outputs(blue_stack_name)
        green_outputs = self.get_stack_outputs(green_stack_name)

        if not all([alb_outputs, blue_outputs, green_outputs]):
            print("Error: Unable to get stack outputs")
            return False

        listener_arn = alb_outputs.get('HTTPListenerArn')
        target_tg_arn = green_outputs.get('TargetGroupArn') if target_environment.lower() == 'green' else blue_outputs.get('TargetGroupArn')

        if not all([listener_arn, target_tg_arn]):
            print("Error: Missing required ARNs")
            return False

        # Create IP-based canary rule
        rule_arn = self.create_ip_based_canary_rule(
            listener_arn=listener_arn,
            target_group_arn=target_tg_arn,
            ip_addresses=canary_ips,
            rule_priority=100
        )

        if not rule_arn:
            print("Failed to create canary rule")
            return False

        print(f"IP-based canary deployment active for {target_environment} environment")
        print("Manual testing can now be performed from specified IP addresses")

        return rule_arn  # Return rule ARN for cleanup

    def gradual_traffic_shift_with_conditions(self, environment: str, application: str,
                                            target_environment: str, shift_percentage: int = 10,
                                            validation_minutes: int = 5,
                                            auto_proceed: bool = False,
                                            metric_validation: bool = True) -> bool:
        """Perform gradual traffic shift with flexible trigger conditions"""

        # Get stack information
        alb_stack_name = f"{environment}-{application}-alb-blue-green"
        blue_stack_name = f"{environment}-{application}-ec2-blue"
        green_stack_name = f"{environment}-{application}-ec2-green"

        alb_outputs = self.get_stack_outputs(alb_stack_name)
        blue_outputs = self.get_stack_outputs(blue_stack_name)
        green_outputs = self.get_stack_outputs(green_stack_name)

        if not all([alb_outputs, blue_outputs, green_outputs]):
            print("Error: Unable to get stack outputs")
            return False

        listener_arn = alb_outputs.get('HTTPListenerArn')
        blue_tg_arn = blue_outputs.get('TargetGroupArn')
        green_tg_arn = green_outputs.get('TargetGroupArn')
        load_balancer_name = alb_outputs.get('LoadBalancerFullName', '')

        if not all([listener_arn, blue_tg_arn, green_tg_arn]):
            print("Error: Missing required ARNs")
            return False

        # Determine current and target weights
        current_blue_weight = int(alb_outputs.get('BlueTrafficWeight', 100))
        current_green_weight = int(alb_outputs.get('GreenTrafficWeight', 0))

        print(f"Current traffic distribution - Blue: {current_blue_weight}%, Green: {current_green_weight}%")

        # Calculate shift direction and steps
        if target_environment.lower() == 'green':
            steps = list(range(current_green_weight, 101, shift_percentage))
            if steps[-1] != 100:
                steps.append(100)
        else:
            steps = list(range(current_blue_weight, 101, shift_percentage))
            if steps[-1] != 100:
                steps.append(100)

        print(f"Traffic shift plan: {steps}")

        # Perform gradual shift with enhanced validation
        for step_weight in steps:
            if target_environment.lower() == 'green':
                green_weight = step_weight
                blue_weight = 100 - step_weight
            else:
                blue_weight = step_weight
                green_weight = 100 - step_weight

            print(f"\n--- Shifting traffic to Blue: {blue_weight}%, Green: {green_weight}% ---")

            # Update weights
            if not self.update_listener_weights(listener_arn, blue_tg_arn, green_tg_arn,
                                              blue_weight, green_weight):
                print("Failed to update weights, rolling back...")
                return False

            # Wait for propagation
            print("Waiting 30 seconds for traffic distribution propagation...")
            time.sleep(30)

            # Health check validation
            blue_healthy, blue_total = self.check_target_group_health(blue_tg_arn)
            green_healthy, green_total = self.check_target_group_health(green_tg_arn)

            print(f"Blue targets: {blue_healthy}/{blue_total} healthy")
            print(f"Green targets: {green_healthy}/{green_total} healthy")

            # Validate target environment health
            if target_environment.lower() == 'green' and green_weight > 0:
                if green_healthy == 0:
                    print("Error: Green environment has no healthy targets")
                    return False
            elif target_environment.lower() == 'blue' and blue_weight > 0:
                if blue_healthy == 0:
                    print("Error: Blue environment has no healthy targets")
                    return False

            if step_weight < 100:
                # Metric-based validation
                if metric_validation and load_balancer_name:
                    print("Performing metric validation...")
                    if not self.validate_metrics(load_balancer_name):
                        print("Metric validation failed. Rolling back...")
                        return False

                # Flexible trigger conditions
                if auto_proceed:
                    print(f"Auto-proceeding after {validation_minutes} minutes...")
                    time.sleep(validation_minutes * 60)
                else:
                    # Manual confirmation for each step
                    user_input = input(f"Continue to next step? (y/n/auto): ").lower()
                    if user_input == 'n':
                        print("Traffic shift stopped by user")
                        return False
                    elif user_input == 'auto':
                        auto_proceed = True
                        print("Switching to automatic mode for remaining steps")
                        time.sleep(validation_minutes * 60)
                    elif user_input == 'y':
                        print("Proceeding to next step...")
                    else:
                        print("Invalid input. Waiting validation period...")
                        time.sleep(validation_minutes * 60)

        print(f"\nTraffic shift to {target_environment} completed successfully!")
        return True

    def emergency_rollback(self, environment: str, application: str) -> bool:
        """Emergency rollback to Blue environment"""
        print("!!! EMERGENCY ROLLBACK INITIATED !!!")

        alb_stack_name = f"{environment}-{application}-alb-blue-green"
        blue_stack_name = f"{environment}-{application}-ec2-blue"
        green_stack_name = f"{environment}-{application}-ec2-green"

        alb_outputs = self.get_stack_outputs(alb_stack_name)
        blue_outputs = self.get_stack_outputs(blue_stack_name)
        green_outputs = self.get_stack_outputs(green_stack_name)

        listener_arn = alb_outputs.get('HTTPListenerArn')
        blue_tg_arn = blue_outputs.get('TargetGroupArn')
        green_tg_arn = green_outputs.get('TargetGroupArn')

        # Immediate switch to Blue 100%
        success = self.update_listener_weights(listener_arn, blue_tg_arn, green_tg_arn, 100, 0)

        if success:
            print("Emergency rollback to Blue completed!")
        else:
            print("Emergency rollback failed!")

        return success


def main():
    parser = argparse.ArgumentParser(description='Advanced Blue-Green Deployment Traffic Manager')
    parser.add_argument('--environment', required=True, help='Environment name (poc, dev, stg, prod)')
    parser.add_argument('--application', required=True, help='Application name')
    parser.add_argument('--action', required=True,
                       choices=['shift', 'rollback', 'canary-ip', 'cleanup-rule'],
                       help='Action to perform')
    parser.add_argument('--target', choices=['blue', 'green'], help='Target environment for shift')
    parser.add_argument('--percentage', type=int, default=10, help='Shift percentage per step (default: 10)')
    parser.add_argument('--validation-minutes', type=int, default=5, help='Validation wait time in minutes (default: 5)')
    parser.add_argument('--auto-proceed', action='store_true', help='Auto-proceed without manual confirmation')
    parser.add_argument('--metric-validation', action='store_true', help='Enable metric-based validation')
    parser.add_argument('--canary-ips', nargs='+', help='IP addresses for canary deployment')
    parser.add_argument('--rule-arn', help='Listener rule ARN to cleanup')
    parser.add_argument('--region', default='ap-northeast-1', help='AWS region (default: ap-northeast-1)')

    args = parser.parse_args()

    # Validate arguments
    if args.action == 'shift' and not args.target:
        print("Error: --target is required for shift action")
        sys.exit(1)

    if args.action == 'canary-ip' and not args.canary_ips:
        print("Error: --canary-ips is required for canary-ip action")
        sys.exit(1)

    if args.action == 'cleanup-rule' and not args.rule_arn:
        print("Error: --rule-arn is required for cleanup-rule action")
        sys.exit(1)

    # Initialize manager
    manager = AdvancedBlueGreenTrafficManager(region=args.region)

    # Perform action
    success = True
    if args.action == 'shift':
        success = manager.gradual_traffic_shift_with_conditions(
            environment=args.environment,
            application=args.application,
            target_environment=args.target,
            shift_percentage=args.percentage,
            validation_minutes=args.validation_minutes,
            auto_proceed=args.auto_proceed,
            metric_validation=args.metric_validation
        )
    elif args.action == 'rollback':
        success = manager.emergency_rollback(
            environment=args.environment,
            application=args.application
        )
    elif args.action == 'canary-ip':
        rule_arn = manager.ip_based_canary_deployment(
            environment=args.environment,
            application=args.application,
            canary_ips=args.canary_ips,
            target_environment=args.target
        )
        if rule_arn:
            print(f"Canary rule created: {rule_arn}")
            print("To cleanup later, use: --action cleanup-rule --rule-arn <ARN>")
        success = bool(rule_arn)
    elif args.action == 'cleanup-rule':
        success = manager.delete_listener_rule(args.rule_arn)

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
