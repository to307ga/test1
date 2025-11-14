#!/usr/bin/env python3
"""
Blue-Green Deployment Traffic Switch Script
Gradual traffic shifting between Blue and Green environments with validation
"""

import boto3
import time
import json
import sys
import argparse
from typing import Dict, List, Tuple
from botocore.exceptions import ClientError


class BlueGreenTrafficManager:
    def __init__(self, region: str = 'ap-northeast-1'):
        """Initialize Blue-Green Traffic Manager"""
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

    def get_cloudwatch_metrics(self, load_balancer_name: str, target_group_name: str,
                              metric_name: str, minutes: int = 5) -> float:
        """Get CloudWatch metrics for monitoring"""
        try:
            end_time = time.time()
            start_time = end_time - (minutes * 60)

            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName=metric_name,
                Dimensions=[
                    {'Name': 'LoadBalancer', 'Value': load_balancer_name},
                    {'Name': 'TargetGroup', 'Value': target_group_name}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=60,
                Statistics=['Average']
            )

            if response['Datapoints']:
                return sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
            else:
                return 0.0

        except ClientError as e:
            print(f"Error getting CloudWatch metrics: {e}")
            return 0.0

    def gradual_traffic_shift(self, environment: str, application: str,
                            target_environment: str, shift_percentage: int = 10,
                            validation_minutes: int = 5) -> bool:
        """Perform gradual traffic shift between Blue and Green environments"""

        # Get stack information
        alb_stack_name = f"{environment}-{application}-alb-blue-green"
        blue_stack_name = f"{environment}-{application}-ec2-blue"
        green_stack_name = f"{environment}-{application}-ec2-green"

        # Get ALB configuration
        alb_outputs = self.get_stack_outputs(alb_stack_name)
        blue_outputs = self.get_stack_outputs(blue_stack_name)
        green_outputs = self.get_stack_outputs(green_stack_name)

        if not all([alb_outputs, blue_outputs, green_outputs]):
            print("Error: Unable to get stack outputs")
            return False

        listener_arn = alb_outputs.get('HTTPListenerArn')
        blue_tg_arn = blue_outputs.get('TargetGroupArn')
        green_tg_arn = green_outputs.get('TargetGroupArn')

        if not all([listener_arn, blue_tg_arn, green_tg_arn]):
            print("Error: Missing required ARNs")
            return False

        # Determine current and target weights
        current_blue_weight = int(alb_outputs.get('BlueTrafficWeight', 100))
        current_green_weight = int(alb_outputs.get('GreenTrafficWeight', 0))

        print(f"Current traffic distribution - Blue: {current_blue_weight}%, Green: {current_green_weight}%")

        # Calculate shift direction and steps
        if target_environment.lower() == 'green':
            # Shift traffic to Green
            steps = list(range(current_green_weight, 101, shift_percentage))
            if steps[-1] != 100:
                steps.append(100)
        else:
            # Shift traffic to Blue
            steps = list(range(current_blue_weight, 101, shift_percentage))
            if steps[-1] != 100:
                steps.append(100)

        print(f"Traffic shift plan: {steps}")

        # Perform gradual shift
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

            # Wait for validation period
            if step_weight < 100:
                print(f"Waiting {validation_minutes} minutes for validation...")
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
    parser = argparse.ArgumentParser(description='Blue-Green Deployment Traffic Manager')
    parser.add_argument('--environment', required=True, help='Environment name (poc, dev, stg, prod)')
    parser.add_argument('--application', required=True, help='Application name')
    parser.add_argument('--action', required=True, choices=['shift', 'rollback'], help='Action to perform')
    parser.add_argument('--target', choices=['blue', 'green'], help='Target environment for shift')
    parser.add_argument('--percentage', type=int, default=10, help='Shift percentage per step (default: 10)')
    parser.add_argument('--validation-minutes', type=int, default=5, help='Validation wait time in minutes (default: 5)')
    parser.add_argument('--region', default='ap-northeast-1', help='AWS region (default: ap-northeast-1)')

    args = parser.parse_args()

    # Validate arguments
    if args.action == 'shift' and not args.target:
        print("Error: --target is required for shift action")
        sys.exit(1)

    # Initialize manager
    manager = BlueGreenTrafficManager(region=args.region)

    # Perform action
    if args.action == 'shift':
        success = manager.gradual_traffic_shift(
            environment=args.environment,
            application=args.application,
            target_environment=args.target,
            shift_percentage=args.percentage,
            validation_minutes=args.validation_minutes
        )
    elif args.action == 'rollback':
        success = manager.emergency_rollback(
            environment=args.environment,
            application=args.application
        )

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
