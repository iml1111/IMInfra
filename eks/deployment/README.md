# Deployment 문법 정리

### [metadata](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta)

- name: 해당 디플로이먼트의 이름, 네임스페이스 내에서 고유해야 하며 멱등성을 위해 수정 불가능함.
- namespace: 소속될 네임스페이스 정의, 입력되지 않을 경우 "default" 네임스페이스에 들어가게 됨.
- [labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/): 객체의 범위를 분류할 수 있는 키/밸류 형태의 Map, 주로 유저가 커스텀 용도로 사용할 수 있음.
  - app: 필수는 아니지만 관례적으로 사용되는 듯 함?
- [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/): labels와 비슷한 map의 형태이지만 쿼리를 수행할 수는 없음. 
  구체적을 왜 존재하는지는 아직 모르겠음.

### [spec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/#DeploymentSpec)

- replicas: desired pod의 수 (default: 1)
- [selector](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/label-selector/#LabelSelector): 어떤 pod을 대상으로 디플로이먼트를 적용할지 범주, 공식이라고 보면 됨.
  - matchLabels: 입력된 키/밸류 map에 딱 대응되는 대상을 범주로 삼음. (ex: app: nginx)

- [template](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-template-v1/#PodTemplateSpec): pod의 구성 요소에 대해 다룸.
  - **metadata:** 위의 메타데이터와 완전히 규격이 일치함. 
    여기도 일관적으로 `labels.app`을 넣어주는 편인듯.
  - **spec**: pod 내의 구성요소를 리스트 형태로 다룸.
    - [containers](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Container) []: 각 컨테이너 리스트, 컴포즈 처럼 복수의 컨테이너를 구성할 수 있음.
      - **image:** 컨테이너 이미지 경로, ECR은 자기꺼 그대로 가져올 수 있는지 확인 필요.
      - **imagePullPolicy**: Always, Never, IfNotPresent 
        (:latest 태그일 경우 default는 Always, 그 외에는 IfNotPresent)
      - **ports []**: 복수의 포트 정보를 열 수 있음.
        - containerPort: 진짜 열고자 하는 포트
        - protocol: UDP, TCP, or SCTP (default는 TCP)
      - env []: 환경변수 리스트 
        **(나중에 환경변수는 클라우드 내부에서 저장한 걸 가져오는 방법 리서치 필요)**
        - name: 환경변수 이름 (반드시 C_IDENTIFIER 이여야 함)
        - value: 환경변수 값
      - [**livenessProbe**](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Probe): 컨테이너 수명를 검사함. 
        - tcpSocket
          - port: tcp 프로토콜 특정 포트를 통해 검사함.
      - [**readinessProbe**](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Probe): 컨테이너의 실행 준비 상태 수명를 검사함.
        - tcpSocket
          - port: tcp 프로토콜 특정 포트를 통해 검사함
    - [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/): 포드가 특정 노드에서만 동작할 수 있도록 하는 범주 분류기
      - **nodegroup-type: 쿠버네티스 정식 문서에서는 일단 안보임, EKS에서만 고유한듯?**

# References

- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/